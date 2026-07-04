#!/usr/bin/env bash
# release-check.sh — the release privacy guard (spec AC-03).
# Scans everything under plugins/ against scripts/forbidden-list.txt.
# Exit 0: clean (release may proceed). Exit 1: match found (release must not proceed).
# --override "<rationale>": records the override to docs/release-overrides.log, then exits 0.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$ROOT/scripts/forbidden-list.txt"
LOCAL_LIST="$ROOT/scripts/forbidden-list.local.txt"  # gitignored supplement: sensitive vault-content phrases
SCAN_DIR="$ROOT/plugins"
LOG="$ROOT/docs/release-overrides.log"

OVERRIDE=""
if [ "${1:-}" = "--override" ]; then
  OVERRIDE="${2:-}"
  if [ -z "$OVERRIDE" ]; then
    echo "REFUSED: --override requires a non-empty rationale."
    exit 1
  fi
fi

MATCHES=""
scan_list() {
  while IFS= read -r entry; do
    case "$entry" in ''|'#'*) continue ;; esac
    hit=$(grep -rinF -- "$entry" "$SCAN_DIR" 2>/dev/null)
    [ -n "$hit" ] && MATCHES="${MATCHES}${hit}
"
  done < "$1"
}
scan_list "$LIST"
[ -f "$LOCAL_LIST" ] && scan_list "$LOCAL_LIST"

if [ -z "$MATCHES" ]; then
  echo "clean — release may proceed"
  exit 0
fi

echo "VIOLATED INVARIANT: the shared plugin never contains author-private wiring or content."
echo "Matches (file:line:content):"
printf '%s' "$MATCHES"

if [ -n "$OVERRIDE" ]; then
  mkdir -p "$(dirname "$LOG")"
  n=$(printf '%s' "$MATCHES" | grep -c .)
  printf '%s · %s match(es) · %s\n' "$(date +%Y-%m-%d)" "$n" "$OVERRIDE" >> "$LOG"
  echo "OVERRIDE RECORDED → docs/release-overrides.log — release may proceed."
  exit 0
fi

echo "Release must not proceed. (Deliberate override: release-check.sh --override \"<rationale>\")"
exit 1
