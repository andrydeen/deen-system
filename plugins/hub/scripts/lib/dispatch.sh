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
      hub__write_atomic "$slots/$n/pid" "${HUB_LOCK_PID:-$$}"
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
  local t="$1" pf="$2" sidmode="$3" run="$HUB_DIR/.runs/$1" mode model rules run_abs mt mb
  mode=$(hub_config_get WORKER_AGENT_MODE agent)
  model=$(hub__tget "$t" model)
  run_abs=$(cd "$run" && pwd) || run_abs="$run"
  # {{TICKET}} and {{RUN_DIR}} (absolute; the worker's progress.log lives there, outside
  # the project, so it is never committed). Plain string replace: paths may hold / & etc.
  rules=$(python3 -c 'import sys; print(open(sys.argv[1], encoding="utf-8").read().replace("{{TICKET}}", sys.argv[2]).replace("{{RUN_DIR}}", sys.argv[3]), end="")' \
    "$HUB_PLUGIN_ROOT/templates/worker-rules.md" "$t" "$run_abs")
  # per-ticket overrides (hub new --max-turns / --max-budget-usd, or hub set)
  mt=$(hub__tget "$t" max_turns); [ -n "$mt" ] || mt="${HUB_MAX_TURNS:-150}"
  mb=$(hub__tget "$t" max_budget_usd); [ -n "$mb" ] || mb="${HUB_MAX_BUDGET_USD:-8}"
  HUB_CMD=(claude -p "$(cat "$pf")")
  if [ "$mode" = inline ]; then
    [ -z "$model" ] || HUB_CMD+=(--model "$model")
    HUB_CMD+=(--append-system-prompt-file "$HUB_PLUGIN_ROOT/agents/hub-worker.md")
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
  HUB_CMD+=(--add-dir "$run_abs"
    --permission-mode auto --allowedTools "Write,Edit,Read,Glob,Grep"
    --disallowedTools "Bash(git push:*),Bash(git merge:*)"
    --output-format stream-json --verbose
    --max-turns "$mt" --max-budget-usd "$mb")
}

# hub_finish_round <ticket> <exit-code|dead|interrupted|stopped>
# The pid file is removed LAST in every branch: its disappearance tells waiters that
# all bookkeeping is done.
hub_finish_round() {
  local t="$1" how="$2" run="$HUB_DIR/.runs/$1" now st denied note off cp i
  now=$(hub_now)
  case "$how" in
    interrupted)
      hub__write_atomic "$run/status" interrupted
      rm -f -- "$run/interrupted"
      hub_slot_release "$t"
      hub_log "$t" "interrupted"
      rm -f -- "$run/pid"
      ;;
    stopped)
      hub__write_atomic "$run/status" stopped
      hub__tset "$t" status stopped
      hub_slot_release "$t"
      rm -f -- "$run/stop" "$run/interrupted" "$run/was-interrupted" "$run/pending"/*.md
      echo "$now stopped $t" >> "$HUB_DIR/.runs/events.log"
      hub_log "$t" "stopped"
      rm -f -- "$run/pid"
      ;;
    dead)
      # the round's shell is gone; do not leave its claude process running unwatched
      cp=$(cat "$run/claude-pid" 2>/dev/null)
      if hub_pid_alive "$cp"; then
        kill -INT "$cp" 2>/dev/null
        i=0
        while [ "$i" -lt 10 ] && hub_pid_alive "$cp"; do sleep 0.2; i=$((i + 1)); done
        hub_pid_alive "$cp" && kill -TERM "$cp" 2>/dev/null
      fi
      rm -f -- "$run/claude-pid"
      hub__write_atomic "$run/status" failed
      hub_slot_release "$t"
      hub__tset "$t" status failed
      echo "$now failed $t worker died" >> "$HUB_DIR/.runs/events.log"
      hub_log "$t" "worker died"
      rm -f -- "$run/pid"
      ;;
    *)
      off=$(cat "$run/events-offset" 2>/dev/null); off=${off:-0}
      tail -c +$((off + 1)) "$run/events.jsonl" > "$run/events-round.jsonl" 2>/dev/null
      python3 "$HUB_LIB/events.py" final "$run/events-round.jsonl" > "$run/final.json" 2>/dev/null
      st=""; denied=0; note=""
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
dt = d.get("denied_tools") or []
print("permission denied: %s" % dt[0] if dt and d.get("denied", 0) > 0 else
      " ".join(str(d.get("note") or d.get("question") or "").split()))
' "$run/final.json" "$run/report.md" 2>/dev/null)
      if [ -z "$st" ]; then st=unknown-report; denied=0; note="report parse failed"; fi
      if [ "${denied:-0}" -gt 0 ]; then
        st=blocked
        case "$note" in "permission denied:"*) ;; *) note="permission denied: $denied tool call(s)" ;; esac
      fi
      hub__tset "$t" status "$st"
      hub__write_atomic "$run/status" "exited $how"
      date "+%Y-%m-%dT%H:%M:%S" > "$run/ended"
      hub_slot_release "$t"
      echo "$now $st $t${note:+ $note}" >> "$HUB_DIR/.runs/events.log"
      hub_log "$t" "round ended: $st (exit $how)${note:+ — $note}"
      rm -f -- "$run/pid"
      ;;
  esac
}

# hub_exec_worker <cmd...> — exec with default SIGINT/SIGQUIT. Async lists in a
# non-interactive shell leave them ignored, which exec'd children inherit; the real
# claude binary would then ignore `kill -INT`.
hub_exec_worker() {
  exec python3 -c 'import os,signal,sys; signal.signal(signal.SIGINT, signal.SIG_DFL); signal.signal(signal.SIGQUIT, signal.SIG_DFL); os.execvp(sys.argv[1], sys.argv[1:])' "$@"
}

# hub__wait_unless_marker <seconds> <run-dir> [both] — sleeps in 0.2 s steps; returns 1 as
# soon as the stop marker (with "both": also interrupted) appears, 0 when the time is up.
hub__wait_unless_marker() {
  local steps i=0
  steps=$(awk -v s="${1:-0}" 'BEGIN { n = int(s * 5); if (n < 1) n = 1; print n }')
  while [ "$i" -lt "$steps" ]; do
    [ -f "$2/stop" ] && return 1
    [ "${3:-}" = both ] && [ -f "$2/interrupted" ] && return 1
    sleep 0.2; i=$((i + 1))
  done
  return 0
}

# hub__path_missing <ticket> <dir> — the round cannot start: fail the run and the ticket.
hub__path_missing() {
  local run="$HUB_DIR/.runs/$1"
  hub__write_atomic "$run/status" failed; rm -f -- "$run/pid"
  hub__tset "$1" status failed
  hub_log "$1" "project path missing: $2"
  echo "$(hub_now) failed $1 project path missing: $2" >> "$HUB_DIR/.runs/events.log"
}

# hub_round <ticket> <prompt-file> — runs one worker round to completion in this shell.
# Returns the claude exit code (0 when interrupted).
hub_round() {
  local t="$1" pf="$2" run="$HUB_DIR/.runs/$1" cwd path iso base repo main rn sid sidmode
  local slot rc retry=0 pid base_s soff eoff matched poll verdict errtxt
  HUB_LOCK_PID=$(exec sh -c 'echo $PPID'); export HUB_LOCK_PID
  mkdir -p "$run" "$HUB_DIR/.runs/.slots"
  hub__write_atomic "$run/pid" "$HUB_LOCK_PID"

  [ -s "$run/session-id" ] || python3 -c 'import uuid; print(uuid.uuid4())' > "$run/session-id"
  rn=$(cat "$run/round" 2>/dev/null); rn=$(( ${rn:-0} + 1 )); echo "$rn" > "$run/round"

  path=$(hub__tget "$t" path); iso=$(hub__tget "$t" isolation)
  # The project directory (main checkout, or the repo that holds the worktree) must exist.
  [ -n "$path" ] && [ -d "$path" ] || { hub__path_missing "$t" "$path"; return 1; }
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
      if git -C "$repo" show-ref --verify --quiet "refs/heads/hub/$t"; then
        git -C "$repo" worktree add "$cwd" "hub/$t" >"$run/worktree.log" 2>&1
      else
        git -C "$repo" worktree add -b "hub/$t" "$cwd" "$base" >"$run/worktree.log" 2>&1
      fi
      if [ $? -ne 0 ]; then
        hub__write_atomic "$run/status" failed; rm -f -- "$run/pid"
        hub__tset "$t" status failed
        hub_log "$t" "worktree creation failed (see .runs/$t/worktree.log)"
        echo "$(hub_now) failed $t worktree creation failed" >> "$HUB_DIR/.runs/events.log"
        return 1
      fi
    fi
    echo "$cwd" > "$run/worktree"
  fi
  echo "$cwd" > "$run/project"
  [ -d "$cwd" ] || { hub__path_missing "$t" "$cwd"; return 1; }

  poll="${HUB_QUEUE_POLL_S:-10}"
  while ! slot=$(hub_slot_acquire "$t"); do
    hub__write_atomic "$run/status" queued
    if ! hub__wait_unless_marker "$poll" "$run"; then
      hub_lock "$run/lock"
      hub_finish_round "$t" stopped
      hub_unlock "$run/lock"
      return 0
    fi
  done

  hub_now > "$run/started"
  hub__tset "$t" status running
  hub_log "$t" "round $rn started"
  echo "$(hub_now) running $t" >> "$HUB_DIR/.runs/events.log"
  touch "$run/events.jsonl" "$run/stderr.log"
  wc -c < "$run/events.jsonl" | tr -d ' ' > "$run/events-offset"

  # A marker left by an earlier round must not cancel this one.
  hub_lock "$run/lock"
  rm -f -- "$run/interrupted"
  hub__write_atomic "$run/status" running
  hub_unlock "$run/lock"
  base_s="${HUB_RETRY_BASE_S:-30}"
  while :; do
    # Pre-launch checkpoint. claude-pid exists only while the worker process runs, so
    # `hub send` / `hub stop` never signal this (SIGINT-ignoring) subshell.
    hub_lock "$run/lock"
    if [ -f "$run/stop" ]; then
      hub_finish_round "$t" stopped; hub_unlock "$run/lock"; return 0
    fi
    if [ -f "$run/interrupted" ]; then
      hub_finish_round "$t" interrupted; hub_unlock "$run/lock"; return 0
    fi
    hub__drain_pending "$t" "$pf" 1
    if [ -f "$run/session-started" ]; then sidmode=resume; else sidmode=first; fi
    hub_build_cmd "$t" "$pf" "$sidmode"
    soff=$(wc -c < "$run/stderr.log" | tr -d ' '); eoff=$(wc -c < "$run/events.jsonl" | tr -d ' ')
    ( cd "$cwd" && hub_exec_worker "${HUB_CMD[@]}" ) </dev/null >>"$run/events.jsonl" 2>>"$run/stderr.log" &
    pid=$!
    hub__write_atomic "$run/claude-pid" "$pid"
    hub__write_atomic "$run/pid" "$pid"
    hub__write_atomic "$HUB_DIR/.runs/.slots/$slot/pid" "$pid"
    # Known gap: a first attempt that fails before the real binary creates a session
    # makes --resume fail on retry ("No conversation found"). Future: detect that
    # message and fall back to --session-id.
    touch "$run/session-started"
    hub_unlock "$run/lock"
    wait "$pid"; rc=$?
    hub_lock "$run/lock"
    rm -f -- "$run/claude-pid"
    hub__write_atomic "$run/pid" "$HUB_LOCK_PID"
    hub__write_atomic "$HUB_DIR/.runs/.slots/$slot/pid" "$HUB_LOCK_PID"
    if [ -f "$run/stop" ]; then
      hub_finish_round "$t" stopped; hub_unlock "$run/lock"; return 0
    elif [ -f "$run/interrupted" ]; then
      hub_finish_round "$t" interrupted; hub_unlock "$run/lock"; return 0
    fi
    hub__write_atomic "$run/status" finishing
    hub_unlock "$run/lock"
    if [ "$rc" -ne 0 ] && [ "$retry" -lt 3 ]; then
      matched=0
      tail -c +$((eoff + 1)) "$run/events.jsonl" > "$run/events-attempt.jsonl"
      # One pass over this attempt's result lines: "veto" (max turns / budget: never
      # retry), "api" (api_error_status 408/429/5xx: transient) or nothing.
      verdict=$(python3 -c '
import json, sys
v = ""
for l in open(sys.argv[1], encoding="utf-8", errors="replace"):
    try: o = json.loads(l)
    except ValueError: continue
    if not (isinstance(o, dict) and o.get("type") == "result"): continue
    sub = str(o.get("subtype") or "")
    if sub == "error_max_turns" or "budget" in sub:
        print("veto"); sys.exit(0)
    try: s = int(o.get("api_error_status"))
    except (TypeError, ValueError): continue
    if s in (408, 429) or 500 <= s <= 599: v = "api"
print(v)
' "$run/events-attempt.jsonl" 2>/dev/null)
      if [ "$verdict" = veto ]; then
        :
      elif [ "$verdict" = api ]; then
        matched=1
      else
        errtxt=$(tail -c +$((soff + 1)) "$run/stderr.log"; python3 "$HUB_LIB/events.py" errors "$run/events-attempt.jsonl")
        if printf '%s\n' "$errtxt" | grep -E -q -w '408|429|5[0-9][0-9]' \
            || printf '%s\n' "$errtxt" | grep -E -q -i 'overloaded|rate.?limit|timed? ?out|ECONNRESET|socket hang up'; then
          matched=1
        fi
      fi
      if [ "$matched" -eq 1 ]; then
        retry=$((retry + 1))
        hub__write_atomic "$run/status" "retrying $retry"
        hub__wait_unless_marker $(( base_s * (1 << (retry - 1)) )) "$run" both || true
        hub__write_atomic "$run/status" running
        continue
      fi
    fi
    break
  done
  hub_finish_round "$t" "$rc"
  return "$rc"
}

# hub dispatch <ticket> [--wait] [--again]
cmd_dispatch() {
  local t="" wait=0 again=0 run rn pf p tst
  while [ $# -gt 0 ]; do
    case "$1" in
      --wait) wait=1; shift ;;
      --again) again=1; shift ;;
      -*) hub_die "dispatch: unknown option: $1" ;;
      *) [ -z "$t" ] || hub_die "dispatch: one ticket only"; t="$1"; shift ;;
    esac
  done
  [ -n "$t" ] || hub_die "usage: hub dispatch <ticket> [--wait] [--again]"
  tst=$(python3 "$HUB_LIB/tickets.py" get "$t" status) || hub_die "unknown ticket: $t"
  run="$HUB_DIR/.runs/$t"
  mkdir -p "$run"
  hub_lock "$run/lock"
  p=$(cat "$run/pid" 2>/dev/null)
  if hub_pid_alive "$p" || [ "$(cat "$run/status" 2>/dev/null)" = starting ]; then
    hub_unlock "$run/lock"
    hub_die "$t is already running"
  fi
  # A fresh round only from a state that wants one; anything else is a misfire
  # (a follow-up belongs to hub send) unless the human asked for a re-run.
  case "$tst" in
    open|failed|stopped|unknown-report|blocked) ;;
    *) if [ "$again" -eq 0 ]; then
         hub_unlock "$run/lock"
         hub_die "$t is $tst; use hub send for a follow-up or hub dispatch --again to re-run"
       fi ;;
  esac
  rn=$(cat "$run/round" 2>/dev/null); rn=$(( ${rn:-0} + 1 ))
  pf="$run/prompt-$rn.md"
  python3 "$HUB_LIB/tickets.py" brief "$t" > "$pf" || { hub_unlock "$run/lock"; hub_die "cannot read brief of $t"; }
  rm -f -- "$run/stop"
  hub__write_atomic "$run/status" starting
  if [ "$wait" -eq 1 ]; then
    hub_unlock "$run/lock"
    hub_round "$t" "$pf"
    return $?
  fi
  ( hub_round "$t" "$pf" ) >/dev/null 2>&1 &
  p=$!
  disown "$p" 2>/dev/null
  hub__write_atomic "$run/pid" "$p"
  hub_unlock "$run/lock"
  echo "dispatched $t round $rn pid $p"
}

