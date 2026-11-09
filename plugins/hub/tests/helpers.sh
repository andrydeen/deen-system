# Sourced by every test. Provides setup_hub and assertions.
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1

fail() { echo "FAIL ${0##*/}: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "${3:-assert_eq}: expected [$1] got [$2]"; }
assert_file() { [ -e "$1" ] || fail "missing file: $1"; }
assert_grep() { grep -Eq -- "$1" "$2" 2>/dev/null || fail "pattern [$1] not in $2"; }

hub() { "$PLUGIN_ROOT/scripts/hub" "$@"; }

setup_hub() {
  TMP_ROOT="$(mktemp -d)"
  if [ "${KEEP_TMP:-0}" != "1" ]; then
    trap 'rm -r -f -- "$TMP_ROOT"' EXIT
  else
    echo "KEEP_TMP: $TMP_ROOT" >&2
  fi
  export HUB_DIR="$TMP_ROOT/hub dir"
  export APPROVALS_DIR="$TMP_ROOT/approvals"
  export FAKE_CLAUDE_LOG="$TMP_ROOT/fake-claude.log"
  export FAKE_CLAUDE_STATE="$TMP_ROOT/fake-claude-state"
  export HUB_PLUGIN_ROOT="$PLUGIN_ROOT"
  mkdir -p "$APPROVALS_DIR" "$FAKE_CLAUDE_STATE"
  export PATH="$TESTS_DIR:$PATH"
  hub init >/dev/null || fail "hub init"
}

ALL_TMP=""
cleanup() {
  pkill -f "$TESTS_DIR/fake-claude" 2>/dev/null
  pkill -f "$TESTS_DIR/claude" 2>/dev/null
  [ "${KEEP_TMP:-0}" = 1 ] && return 0
  local d
  for d in $ALL_TMP; do rm -r -f -- "$d"; done
}
trap cleanup EXIT

# log_py <py-expr-on-list-of-entries> — evaluates against FAKE_CLAUDE_LOG (JSONL).
log_py() {
  python3 -c 'import json,sys
E=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
'"$1" "$FAKE_CLAUDE_LOG"
}

real() { python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }

setup_projects() {
  setup_hub
  ALL_TMP="$ALL_TMP $TMP_ROOT"
  trap cleanup EXIT
  mkdir -p "$HUB_DIR/demo proj" "$HUB_DIR/git proj"
  ( cd "$HUB_DIR/git proj" && git init -q -b main && git config user.email t@t && git config user.name t \
    && echo x > f && git add f && git commit -q -m init ) || fail "git init"
  printf 'demo:\n  path: "%s/demo proj"\n  isolation: none\ngitproj:\n  path: "%s/git proj"\n  isolation: worktree\n' \
    "$HUB_DIR" "$HUB_DIR" > "$HUB_DIR/projects.yaml"
}
