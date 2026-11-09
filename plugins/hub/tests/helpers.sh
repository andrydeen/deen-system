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
