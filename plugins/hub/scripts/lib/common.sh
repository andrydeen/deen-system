# common.sh — shared helpers for hub. Sourced by scripts/hub. bash 3.2 safe.
HUB_DIR="${HUB_DIR:-$HOME/Projects/Hub}"
APPROVALS_DIR="${APPROVALS_DIR:-$HOME/.deen-system/approvals}"
export HUB_DIR APPROVALS_DIR

hub_die() { echo "hub: $*" >&2; exit 1; }

hub_now() { date "+%Y-%m-%dT%H:%M"; }

# hub_log <ticket> <text> — appends a dated line to the ticket's Log section.
hub_log() {
  python3 "$HUB_LIB/tickets.py" note "$1" "$2"
}

hub_pid_alive() { [ -n "${1:-}" ] && kill -0 "$1" 2>/dev/null; }

# hub_config_get <KEY> [default] — reads KEY=value lines from $HUB_DIR/config.
hub_config_get() {
  local v=""
  if [ -f "$HUB_DIR/config" ]; then
    v=$(grep "^$1=" "$HUB_DIR/config" | tail -1 | cut -d= -f2-)
  fi
  if [ -n "$v" ]; then echo "$v"; else echo "${2:-}"; fi
}

# hub_lock <dir> [timeout_s] — mkdir-based lock; reclaims locks whose pid is dead.
hub_lock() {
  local dir="$1" timeout="${2:-10}" waited=0 p
  while ! mkdir "$dir" 2>/dev/null; do
    if [ -f "$dir/pid" ]; then
      p=$(cat "$dir/pid" 2>/dev/null)
      if [ -n "$p" ] && ! hub_pid_alive "$p"; then
        rm -r -f -- "$dir"
        continue
      fi
    fi
    if [ "$waited" -ge $((timeout * 10)) ]; then
      hub_die "timed out waiting for lock: $dir"
    fi
    sleep 0.1
    waited=$((waited + 1))
  done
  echo "${HUB_LOCK_PID:-$$}" > "$dir/pid"
}

hub_unlock() { rm -r -f -- "$1"; }

# hub init [--hub-dir D] [--worker-agent-mode M] [--event-delivery E]
cmd_init() {
  local mode="agent" delivery="monitor"
  while [ $# -gt 0 ]; do
    case "$1" in
      --hub-dir) HUB_DIR="${2:?--hub-dir needs a value}"; export HUB_DIR; shift 2 ;;
      --worker-agent-mode) mode="${2:?needs a value}"; shift 2 ;;
      --event-delivery) delivery="${2:?needs a value}"; shift 2 ;;
      *) hub_die "init: unknown option: $1" ;;
    esac
  done
  mkdir -p "$HUB_DIR/tickets" "$HUB_DIR/.runs/.slots" "$HUB_DIR/bin" \
    || hub_die "cannot create $HUB_DIR"
  if [ ! -f "$HUB_DIR/config" ]; then
    printf 'WORKER_AGENT_MODE=%s\nEVENT_DELIVERY=%s\n' "$mode" "$delivery" > "$HUB_DIR/config"
  fi
  if [ ! -f "$HUB_DIR/projects.yaml" ]; then
    cp "$HUB_PLUGIN_ROOT/templates/projects.yaml.example" "$HUB_DIR/projects.yaml"
  fi
  if [ ! -f "$HUB_DIR/INDEX.md" ]; then
    printf '# Hub index\n\n' > "$HUB_DIR/INDEX.md"
  fi
  [ -f "$HUB_DIR/.runs/events.log" ] || : > "$HUB_DIR/.runs/events.log"
  cat > "$HUB_DIR/bin/hub" <<'WRAP'
#!/usr/bin/env bash
root="${HUB_PLUGIN_ROOT:-}"
if [ -z "$root" ]; then
  newest=$(ls -d "$HOME"/.claude/plugins/cache/*/hub/*/scripts/hub 2>/dev/null | sort | tail -1)
  root="${newest%/scripts/hub}"
fi
[ -n "$root" ] || { echo "hub: plugin not found (set HUB_PLUGIN_ROOT)" >&2; exit 1; }
exec "$root/scripts/hub" "$@"
WRAP
  chmod +x "$HUB_DIR/bin/hub"
  echo "hub initialised at $HUB_DIR"
}
