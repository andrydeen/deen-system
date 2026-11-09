# hub watch — one watchdog pass (flags stalled / looping / dead / over-budget workers).

# hub__watch_dead <ticket> — succeeds when the run is in a live status and its pid is
# missing or not alive (i.e. the worker really is dead).
hub__watch_dead() {
  local run="$HUB_DIR/.runs/$1" st pid
  st=$(cat "$run/status" 2>/dev/null)
  case "$st" in
    starting|queued|running|finishing|"retrying "*) ;;
    *) return 1 ;;
  esac
  pid=$(cat "$run/pid" 2>/dev/null)
  if [ -n "$pid" ] && hub_pid_alive "$pid"; then return 1; fi
  return 0
}

cmd_watch() {
  local out line t rc fl rest
  out=$(python3 "$HUB_LIB/watch.py" watch "$@")
  rc=$?
  [ "$rc" -eq 0 ] || echo "hub: watch.py failed (exit $rc)" >&2
  [ -n "$out" ] && printf '%s\n' "$out"
  while IFS= read -r line; do
    case "$line" in
      "⚠ dead T-"*)
        t=${line#"⚠ dead "}; t=${t%% *}
        case "$t" in T-[0-9]*) ;; *) continue ;; esac
        hub_lock "$HUB_DIR/.runs/$t/lock"
        if hub__watch_dead "$t"; then
          hub_finish_round "$t" dead
        else
          echo "hub: $t recovered, not dead"
          fl=$(python3 "$HUB_LIB/tickets.py" get "$t" flag)
          rest=$(printf '%s' "$fl" | tr ',' '\n' | grep -v '^dead$' | paste -s -d, -)
          python3 "$HUB_LIB/tickets.py" set "$t" flag "$rest" >/dev/null
        fi
        hub_unlock "$HUB_DIR/.runs/$t/lock"
        ;;
    esac
  done <<< "$out"
  return 0
}
