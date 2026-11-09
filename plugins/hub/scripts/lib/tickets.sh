# tickets.sh — ticket subcommands; thin wrappers around tickets.py. bash 3.2 safe.

cmd_new() {
  local rc
  mkdir -p "$HUB_DIR/.runs"
  hub_lock "$HUB_DIR/.runs/.idlock" || return 1
  python3 "$HUB_LIB/tickets.py" new "$@"
  rc=$?
  hub_unlock "$HUB_DIR/.runs/.idlock"
  return $rc
}

cmd_note() { python3 "$HUB_LIB/tickets.py" note "$@"; }
cmd_set() { python3 "$HUB_LIB/tickets.py" set "$@"; }
cmd_ticket() { python3 "$HUB_LIB/tickets.py" "$@"; }
