# Sourced by scripts/hub: board, show, events.
cmd_board() { python3 "$HUB_LIB/board.py" board "$@"; }
cmd_show() { python3 "$HUB_LIB/board.py" show "$@"; }

cmd_events() {
  local n=20 follow=1
  while [ $# -gt 0 ]; do
    case "$1" in
      --since) [ $# -ge 2 ] || { echo "hub: --since needs a number" >&2; return 1; }; n="$2"; shift 2 ;;
      --no-follow) follow=0; shift ;;
      *) echo "usage: hub events [--since N] [--no-follow]" >&2; return 1 ;;
    esac
  done
  case "$n" in ''|*[!0-9]*) echo "hub: --since needs a number" >&2; return 1 ;; esac
  local log="$HUB_DIR/.runs/events.log"
  if [ "$follow" = 1 ]; then
    tail -n "$n" -F "$log"
  else
    tail -n "$n" "$log"
  fi
}
