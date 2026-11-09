# dispatch.sh — hub dispatch and the worker-round machinery. bash 3.2 safe.
#
# Env knobs: HUB_MAX_WORKERS (4), HUB_MAX_TURNS (150), HUB_MAX_BUDGET_USD (8),
# HUB_RETRY_BASE_S (30; retries sleep base*1, *2, *4), HUB_QUEUE_POLL_S (10;
# seconds between slot checks while queued — tests lower it).

hub__tget() { python3 "$HUB_LIB/tickets.py" get "$1" "$2"; }
hub__tset() { python3 "$HUB_LIB/tickets.py" set "$1" "$2" "$3" >/dev/null; }

# hub_slot_acquire <ticket> — claims a free slot; prints its number. Returns 1 if none free.
hub_slot_acquire() {
  local t="$1" slots="$HUB_DIR/.runs/.slots" n max p
  max="${HUB_MAX_WORKERS:-4}"
  mkdir -p "$slots"
  hub_lock "$HUB_DIR/.runs/.slots.lock" 30 || return 1
  n=1
  while [ "$n" -le "$max" ]; do
    if [ -d "$slots/$n" ]; then
      p=$(cat "$slots/$n/pid" 2>/dev/null)
      if [ -z "$p" ] || ! hub_pid_alive "$p"; then
        rm -r -f -- "$slots/$n"
      fi
    fi
    if mkdir "$slots/$n" 2>/dev/null; then
      echo "${HUB_LOCK_PID:-$$}" > "$slots/$n/pid"
      echo "$t" > "$slots/$n/ticket"
      echo "$n" > "$HUB_DIR/.runs/$t/slot"
      hub_unlock "$HUB_DIR/.runs/.slots.lock"
      echo "$n"
      return 0
    fi
    n=$((n + 1))
  done
  hub_unlock "$HUB_DIR/.runs/.slots.lock"
  return 1
}

# hub_slot_release <ticket>
hub_slot_release() {
  local run="$HUB_DIR/.runs/$1" n
  [ -f "$run/slot" ] || return 0
  n=$(cat "$run/slot")
  case "$n" in ''|*[!0-9]*) ;; *) rm -r -f -- "$HUB_DIR/.runs/.slots/$n" ;; esac
  rm -f -- "$run/slot"
}

# hub_build_cmd <ticket> <prompt-file> <first|resume> — fills the global array HUB_CMD.
hub_build_cmd() {
  local t="$1" pf="$2" sidmode="$3" run="$HUB_DIR/.runs/$1" mode model rules
  mode=$(hub_config_get WORKER_AGENT_MODE agent)
  model=$(hub__tget "$t" model)
  rules=$(sed "s/{{TICKET}}/$t/g" "$HUB_PLUGIN_ROOT/templates/worker-rules.md")
  HUB_CMD=(claude -p "$(cat "$pf")")
  if [ "$mode" = inline ]; then
    HUB_CMD+=(--model "$model" --append-system-prompt-file "$HUB_PLUGIN_ROOT/agents/hub-worker.md")
  else
    HUB_CMD+=(--agent hub-worker)
    [ -z "$model" ] || HUB_CMD+=(--model "$model")
  fi
  HUB_CMD+=(--append-system-prompt "$rules")
  if [ "$sidmode" = first ]; then
    HUB_CMD+=(--session-id "$(cat "$run/session-id")")
  else
    HUB_CMD+=(--resume "$(cat "$run/session-id")")
  fi
  HUB_CMD+=(--permission-mode auto --allowedTools "Write,Edit,Read,Glob,Grep"
    --output-format stream-json --verbose
    --max-turns "${HUB_MAX_TURNS:-150}" --max-budget-usd "${HUB_MAX_BUDGET_USD:-8}")
}

# hub_finish_round <ticket> <exit-code|dead|interrupted>
hub_finish_round() {
  local t="$1" how="$2" run="$HUB_DIR/.runs/$1" now st denied note off
  now=$(hub_now)
  case "$how" in
    interrupted)
      echo interrupted > "$run/status"
      rm -f -- "$run/interrupted" "$run/pid"
      hub_slot_release "$t"
      hub_log "$t" "interrupted"
      ;;
    dead)
      echo failed > "$run/status"
      rm -f -- "$run/pid"
      hub_slot_release "$t"
      hub__tset "$t" status failed
      echo "$now failed $t worker died" >> "$HUB_DIR/.runs/events.log"
      hub_log "$t" "worker died"
      ;;
    *)
      off=$(cat "$run/events-offset" 2>/dev/null); off=${off:-0}
      tail -c +$((off + 1)) "$run/events.jsonl" > "$run/events-round.jsonl" 2>/dev/null
      python3 "$HUB_LIB/events.py" final "$run/events-round.jsonl" > "$run/final.json"
      {
        IFS= read -r st
        IFS= read -r denied
        IFS= read -r note
      } < <(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
open(sys.argv[2], "w").write(d.get("text") or "")
print(d.get("status", "unknown-report"))
print(d.get("denied", 0))
print(" ".join(str(d.get("note") or d.get("question") or "").split()))
' "$run/final.json" "$run/report.md")
      if [ "${denied:-0}" -gt 0 ]; then
        st=blocked
        note="permission denied: $denied tool call(s)"
      fi
      hub__tset "$t" status "$st"
      echo "exited $how" > "$run/status"
      date "+%Y-%m-%dT%H:%M:%S" > "$run/ended"
      rm -f -- "$run/pid"
      hub_slot_release "$t"
      echo "$now $st $t $note" >> "$HUB_DIR/.runs/events.log"
      hub_log "$t" "round ended: $st (exit $how)${note:+ — $note}"
      ;;
  esac
}

# hub_round <ticket> <prompt-file> — runs one worker round to completion in this shell.
# Returns the claude exit code (0 when interrupted).
hub_round() {
  local t="$1" pf="$2" run="$HUB_DIR/.runs/$1" cwd path iso base repo main rn sid sidmode
  local slot rc retry=0 pid base_s soff eoff matched poll
  HUB_LOCK_PID=$(sh -c 'echo $PPID'); export HUB_LOCK_PID
  mkdir -p "$run" "$HUB_DIR/.runs/.slots"
  echo "$HUB_LOCK_PID" > "$run/pid"

  [ -s "$run/session-id" ] || python3 -c 'import uuid; print(uuid.uuid4())' > "$run/session-id"
  rn=$(cat "$run/round" 2>/dev/null); rn=$(( ${rn:-0} + 1 )); echo "$rn" > "$run/round"

  path=$(hub__tget "$t" path); iso=$(hub__tget "$t" isolation)
  if [ "$iso" = none ]; then
    cwd="$path"
  else
    repo="$path"; cwd="$repo/.claude/worktrees/$t"
    if [ ! -d "$cwd" ]; then
      if [ "$(hub__tget "$t" base)" = head ]; then
        base=HEAD
      else
        main=$(hub__tget "$t" project)
        base=$(python3 "$HUB_LIB/tickets.py" projects | python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1],{}).get("main","main"))' "$main")
      fi
      if ! git -C "$repo" worktree add -b "hub/$t" "$cwd" "$base" >"$run/worktree.log" 2>&1; then
        echo failed > "$run/status"; rm -f -- "$run/pid"
        hub__tset "$t" status failed
        hub_log "$t" "worktree creation failed (see .runs/$t/worktree.log)"
        echo "$(hub_now) failed $t worktree creation failed" >> "$HUB_DIR/.runs/events.log"
        return 1
      fi
    fi
    echo "$cwd" > "$run/worktree"
  fi
  echo "$cwd" > "$run/project"

  poll="${HUB_QUEUE_POLL_S:-10}"
  while ! slot=$(hub_slot_acquire "$t"); do
    echo queued > "$run/status"
    sleep "$poll"
  done

  hub_now > "$run/started"
  echo running > "$run/status"
  hub__tset "$t" status running
  hub_log "$t" "round $rn started"
  echo "$(hub_now) running $t" >> "$HUB_DIR/.runs/events.log"
  touch "$run/events.jsonl" "$run/stderr.log"
  wc -c < "$run/events.jsonl" | tr -d ' ' > "$run/events-offset"

  # (Task 5: drain pending/ here and append it to the prompt.)
  base_s="${HUB_RETRY_BASE_S:-30}"
  while :; do
    if [ -f "$run/session-started" ]; then sidmode=resume; else sidmode=first; fi
    hub_build_cmd "$t" "$pf" "$sidmode"
    soff=$(wc -c < "$run/stderr.log" | tr -d ' '); eoff=$(wc -c < "$run/events.jsonl" | tr -d ' ')
    ( cd "$cwd" && exec "${HUB_CMD[@]}" ) </dev/null >>"$run/events.jsonl" 2>>"$run/stderr.log" &
    pid=$!
    echo "$pid" > "$run/pid"
    echo "$pid" > "$HUB_DIR/.runs/.slots/$slot/pid"
    touch "$run/session-started"
    wait "$pid"; rc=$?
    if [ -f "$run/interrupted" ]; then
      hub_finish_round "$t" interrupted
      return 0
    fi
    if [ "$rc" -ne 0 ] && [ "$retry" -lt 3 ]; then
      matched=0
      { tail -c +$((soff + 1)) "$run/stderr.log"; tail -c +$((eoff + 1)) "$run/events.jsonl"; } \
        | grep -E -q -i '408|429|5[0-9][0-9]|overloaded|rate.?limit|timed? ?out|ECONNRESET|socket hang up' && matched=1
      if [ "$matched" -eq 1 ]; then
        retry=$((retry + 1))
        echo "retrying $retry" > "$run/status"
        sleep $(( base_s * (1 << (retry - 1)) ))
        echo running > "$run/status"
        continue
      fi
    fi
    break
  done
  hub_finish_round "$t" "$rc"
  return "$rc"
}

# hub dispatch <ticket> [--wait]
cmd_dispatch() {
  local t="" wait=0 run rn pf p
  while [ $# -gt 0 ]; do
    case "$1" in
      --wait) wait=1; shift ;;
      -*) hub_die "dispatch: unknown option: $1" ;;
      *) [ -z "$t" ] || hub_die "dispatch: one ticket only"; t="$1"; shift ;;
    esac
  done
  [ -n "$t" ] || hub_die "usage: hub dispatch <ticket> [--wait]"
  python3 "$HUB_LIB/tickets.py" get "$t" status >/dev/null || hub_die "unknown ticket: $t"
  run="$HUB_DIR/.runs/$t"
  p=$(cat "$run/pid" 2>/dev/null)
  if hub_pid_alive "$p"; then hub_die "$t is already running"; fi
  mkdir -p "$run"
  rn=$(cat "$run/round" 2>/dev/null); rn=$(( ${rn:-0} + 1 ))
  pf="$run/prompt-$rn.md"
  python3 "$HUB_LIB/tickets.py" brief "$t" > "$pf" || hub_die "cannot read brief of $t"
  if [ "$wait" -eq 1 ]; then
    hub_round "$t" "$pf"
    return $?
  fi
  ( hub_round "$t" "$pf" ) >/dev/null 2>&1 &
  p=$!
  disown "$p" 2>/dev/null
  echo "dispatched $t round $rn pid $p"
}
