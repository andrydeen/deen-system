# steer.sh — live steering: hub send (interrupt + resume) and hub stop. bash 3.2 safe.
#
# Protocol: a worker process can be signalled only while .runs/<T>/claude-pid exists
# (hub_round creates it right after launching claude and removes it right after wait).
# Markers: interrupted (restart wanted), stop (end the ticket's round for good).
# The ticket lock (.runs/<T>/lock) is never held while waiting for a process.

# hub__drain_pending <ticket> <prompt-file> [lead-blank=0] — appends every pending text
# (filename order) to the prompt file and briefs.log, then removes them. Caller holds the lock.
hub__drain_pending() {
  local run="$HUB_DIR/.runs/$1" pf="$2" f first=1
  for f in "$run/pending"/*.md; do
    [ -e "$f" ] || continue
    if [ "$first" -eq 0 ] || [ "${3:-0}" = 1 ]; then printf '\n' >> "$pf"; fi
    first=0
    cat "$f" >> "$pf"
    printf -- '- %s %s\n' "$(hub_now)" "$(cat "$f")" >> "$run/briefs.log"
    rm -f -- "$f"
  done
}

# hub_interrupt <ticket> — marks the round interrupted and sends SIGINT to the worker
# process. Caller holds the ticket lock and has checked that claude-pid is alive.
hub_interrupt() {
  local run="$HUB_DIR/.runs/$1"
  touch "$run/interrupted" "$run/was-interrupted"
  kill -INT "$(cat "$run/claude-pid")" 2>/dev/null
  return 0
}

# hub send <ticket> "<text>"
cmd_send() {
  local t="${1:-}" text run cpid pid st waiting=0 i tries=0 ns pf pre rn n
  [ $# -ge 2 ] || hub_die "usage: hub send <ticket> <text>"
  shift
  text="$*"
  [ -n "$text" ] || hub_die "usage: hub send <ticket> <text>"
  python3 "$HUB_LIB/tickets.py" get "$t" status >/dev/null || hub_die "unknown ticket: $t"
  run="$HUB_DIR/.runs/$t"
  [ -s "$run/session-id" ] || hub_die "$t has not been dispatched; use hub dispatch"
  mkdir -p "$run/pending"
  ns=$(python3 -c 'import time; print(time.time_ns())')

  hub_lock "$run/lock"
  printf '%s\n' "$text" > "$run/pending/$ns.md"
  cpid=$(cat "$run/claude-pid" 2>/dev/null)
  # Benign race: a send that reads claude-pid in the instant after the worker exited (before
  # hub_round removes it) treats a completed round as interrupted; its output stays in
  # events.jsonl and the resumed round carries on from it.
  if hub_pid_alive "$cpid"; then
    waiting=1
    [ -f "$run/interrupted" ] || hub_interrupt "$t"
  fi
  hub_unlock "$run/lock"
  hub_log "$t" "sent: $(printf '%s' "$text" | tr '\n' ' ' | cut -c1-80)"

  if [ "$waiting" -eq 1 ]; then
    i=0
    while [ "$i" -lt 150 ]; do
      [ "$(cat "$run/status" 2>/dev/null)" = interrupted ] && break
      [ -f "$run/interrupted" ] || break
      sleep 0.2; i=$((i + 1))
    done
    if [ -f "$run/interrupted" ] && hub_pid_alive "$cpid"; then
      kill -TERM "$cpid" 2>/dev/null
      i=0
      while [ "$i" -lt 25 ] && hub_pid_alive "$cpid"; do sleep 0.2; i=$((i + 1)); done
    fi
  fi

  while :; do
    hub_lock "$run/lock"
    cpid=$(cat "$run/claude-pid" 2>/dev/null)
    pid=$(cat "$run/pid" 2>/dev/null)
    st=$(cat "$run/status" 2>/dev/null)
    if hub_pid_alive "$cpid" || [ "$st" = starting ]; then
      hub_unlock "$run/lock"; echo "queued $t"; return 0
    fi
    if hub_pid_alive "$pid"; then
      # A round is finishing, retrying, queued or about to launch: give it a moment.
      hub_unlock "$run/lock"
      if [ "$tries" -ge 1 ]; then echo "queued $t"; return 0; fi
      tries=1
      i=0
      while [ "$i" -lt 50 ] && [ -e "$run/pid" ]; do sleep 0.2; i=$((i + 1)); done
      continue
    fi
    break
  done
  if [ -z "$(ls -A "$run/pending" 2>/dev/null)" ]; then
    hub_unlock "$run/lock"; echo "queued $t"; return 0
  fi
  hub__write_atomic "$run/status" starting
  rn=$(cat "$run/round" 2>/dev/null); rn=$(( ${rn:-0} + 1 ))
  pf="$run/prompt-$rn.md"
  if [ -f "$run/was-interrupted" ]; then
    pre="Interrupted by the human. Before anything else read $(cd "$run" && pwd)/progress.log and run git status to see what is already done, and state it in one line. New instruction:"
    rm -f -- "$run/was-interrupted"
  else
    pre="Follow-up from the human:"
  fi
  printf '%s\n' "$pre" > "$pf"
  hub__drain_pending "$t" "$pf" 0
  ( hub_round "$t" "$pf" ) >/dev/null 2>&1 &
  n=$!
  disown "$n" 2>/dev/null
  hub__write_atomic "$run/pid" "$n"
  hub_unlock "$run/lock"
  echo "sent $t round $rn pid $n"
}

# hub__clear_markers <ticket> — drops steering left for a round that will not run.
hub__clear_markers() {
  local run="$HUB_DIR/.runs/$1"
  rm -f -- "$run/stop" "$run/interrupted" "$run/was-interrupted" "$run/pending"/*.md
}

# hub__mark_stopped <ticket> — direct status/log update (fallback when the round did not
# record its own stop).
hub__mark_stopped() {
  local run="$HUB_DIR/.runs/$1"
  hub__clear_markers "$1"
  hub__tset "$1" status stopped
  hub__write_atomic "$run/status" stopped
  echo "$(hub_now) stopped $1" >> "$HUB_DIR/.runs/events.log"
  hub_log "$1" "stopped"
}

# hub stop <ticket>
cmd_stop() {
  local t="${1:-}" run pid cpid i
  [ -n "$t" ] || hub_die "usage: hub stop <ticket>"
  python3 "$HUB_LIB/tickets.py" get "$t" status >/dev/null || hub_die "unknown ticket: $t"
  run="$HUB_DIR/.runs/$t"
  mkdir -p "$run"
  hub_lock "$run/lock"
  pid=$(cat "$run/pid" 2>/dev/null)
  if ! hub_pid_alive "$pid"; then
    # Nothing to stop: the ticket's status (ready, done, ...) is left as it is.
    hub__clear_markers "$t"
    hub_unlock "$run/lock"
    echo "stopped $t (was not running)"
    return 0
  fi
  touch "$run/stop"
  cpid=$(cat "$run/claude-pid" 2>/dev/null)
  hub_pid_alive "$cpid" && kill -INT "$cpid" 2>/dev/null
  hub_unlock "$run/lock"
  i=0
  while [ "$i" -lt 200 ] && [ -e "$run/pid" ]; do
    if [ "$i" -eq 150 ]; then
      cpid=$(cat "$run/claude-pid" 2>/dev/null)
      hub_pid_alive "$cpid" && kill -TERM "$cpid" 2>/dev/null
    fi
    sleep 0.2; i=$((i + 1))
  done
  [ ! -e "$run/pid" ] || hub_die "could not stop $t (round still active)"
  rm -f -- "$run/stop"
  [ "$(cat "$run/status" 2>/dev/null)" = stopped ] || hub__mark_stopped "$t"
  echo "stopped $t"
}
