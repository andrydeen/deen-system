# hub watch — one watchdog pass (flags stalled / looping / dead / over-budget workers).

cmd_watch() {
  local out line t
  out=$(python3 "$HUB_LIB/watch.py" watch "$@")
  [ -n "$out" ] && printf '%s\n' "$out"
  while IFS= read -r line; do
    case "$line" in
      "⚠ dead T-"*)
        t=${line#"⚠ dead "}; t=${t%% *}
        case "$t" in T-[0-9]*) hub_finish_round "$t" dead ;; esac
        ;;
    esac
  done <<< "$out"
  return 0
}
