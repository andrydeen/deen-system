#!/usr/bin/env bash
# validate.sh — content checks for the deen plugin's bundled guides.
# Usage: scripts/validate.sh [guide-memory|guide-handoff|guide-claude-code|guide-obsidian|all]
# Exit 0 = all checks pass; exit 1 = failures (each printed).
set -u

REFS="$(cd "$(dirname "$0")/.." && pwd)/plugins/deen/skills/setup/references"
FAIL=0

err() { echo "FAIL: $1"; FAIL=1; }

check_guide() {
  local name="$1" file="$REFS/$1.md"
  [ -f "$file" ] || { err "$name: file missing ($file)"; return; }

  # frontmatter keys (plugin_version is stamped at copy time by setup, not in the bundle)
  grep -q '^type: reference' "$file" || err "$name: frontmatter 'type: reference' missing"
  grep -q '^tags:' "$file" || err "$name: frontmatter 'tags:' missing"
  grep -q '^updated:' "$file" || err "$name: frontmatter 'updated:' missing"

  # plugin-ownership header (ADR-0002): must warn that re-running setup refreshes the copy
  grep -qi 'plugin-owned' "$file" || err "$name: plugin-ownership header missing"
  grep -qi 'refresh' "$file" || err "$name: refresh-behavior note missing"

  # reading time <= 10 min at 200 wpm => <= 2000 words (spec §6)
  local words; words=$(wc -w < "$file" | tr -d ' ')
  [ "$words" -le 2000 ] || err "$name: $words words > 2000 (breaks the <=10-min read NFR)"
}

check_memory_table() {
  local file="$REFS/guide-memory.md"
  [ -f "$file" ] || return  # missing-file already reported
  # the what-goes-where table must name all three layers (AC-05)
  grep -qi 'auto-memory' "$file" || err "guide-memory: table lacks the auto-memory layer"
  grep -qi 'vault' "$file" || err "guide-memory: table lacks the vault layer"
  grep -qiE 'ARCHITECTURE\.md' "$file" || err "guide-memory: table lacks the project layer (ARCHITECTURE.md)"
  grep -qE '^\|.*\|.*\|' "$file" || err "guide-memory: no markdown table found (AC-05 demands one decision table)"
}

check_handoff_content() {
  local file="$REFS/guide-handoff.md"
  [ -f "$file" ] || return
  grep -qi 'precedence' "$file" || err "guide-handoff: precedence rule missing"
  grep -qiE 'two (real |separate )?sessions|session boundary' "$file" || err "guide-handoff: two-session round-trip explanation missing"
}

check_obsidian_content() {
  local file="$REFS/guide-obsidian.md"
  [ -f "$file" ] || return
  grep -qi 'open.*vault' "$file" || err "guide-obsidian: open-the-vault steps missing"
}

check_setup_skill() {
  local file="$REFS/../SKILL.md"
  for g in guide-claude-code guide-memory guide-handoff guide-obsidian; do
    grep -q "references/$g.md" "$file" || err "setup-skill: Step A.4 lacks the $g row (AC-08)"
  done
  grep -q 'plugin_version' "$file" || err "setup-skill: guide version-stamp instruction missing (ADR-0002)"
  grep -qi 'add-only' "$file" || err "setup-skill: add-only re-run rule missing (AC-02)"
  grep -q '/deen:verify' "$file" || err "setup-skill: closing message does not point to /deen:verify"
  grep -qi 'missing prerequisite' "$file" || err "setup-skill: prerequisite-missing outcome missing (AC-02)"
}

check_verify_skill() {
  local file="$REFS/../../verify/SKILL.md"
  [ -f "$file" ] || { err "verify-skill: file missing ($file)"; return; }
  grep -qi 'deen verify' "$file" || err "verify-skill: explicit deen-qualified trigger discipline missing"
  grep -q 'plugin_version' "$file" || err "verify-skill: guide stamp check missing (area 1, AC-08)"
  grep -qi 'what goes where\|memory layer' "$file" || err "verify-skill: memory-layer check missing (area 2)"
  grep -q 'restored:' "$file" || err "verify-skill: round-trip evidence check missing (area 3, AC-04)"
  grep -q '.obsidian' "$file" || err "verify-skill: .obsidian/ check missing (area 4)"
  grep -qi 'remedial\|exact.*step' "$file" || err "verify-skill: red areas must carry remedial steps"
  grep -q '/deen:setup' "$file" || err "verify-skill: not-set-up outcome must point to /deen:setup"
}

check_handoff_skill() {
  local file="$REFS/../../handoff/SKILL.md"
  grep -q 'restored:' "$file" || err "handoff-skill: Mode B does not append the 'restored:' evidence line (AC-04)"
  grep -qi 'handoff_enabled.*false' "$file" || err "handoff-skill: disabled-silent behavior missing (AC-07)"
}

check_readme() {
  local readme="$REFS/../../../../../README.md" skills="$REFS/../.."
  # every shipped skill must be named in the README (ADR-0001: discoverability)
  local d s
  for d in "$skills"/*/; do
    s="$(basename "$d")"
    grep -q "/deen:$s" "$readme" || err "readme: shipped skill /deen:$s is not mentioned in README.md"
  done
}

run() {
  case "$1" in
    readme)            check_readme ;;
    handoff-skill)     check_handoff_skill ;;
    setup-skill)       check_setup_skill ;;
    verify-skill)      check_verify_skill ;;
    guide-memory)      check_guide guide-memory; check_memory_table ;;
    guide-handoff)     check_guide guide-handoff; check_handoff_content ;;
    guide-claude-code) check_guide guide-claude-code ;;
    guide-obsidian)    check_guide guide-obsidian; check_obsidian_content ;;
    all) for g in guide-memory guide-handoff guide-claude-code guide-obsidian; do run "$g"; done; check_readme ;;
    *) echo "unknown target: $1"; exit 2 ;;
  esac
}

run "${1:-all}"
[ "$FAIL" -eq 0 ] && echo "OK: all checks passed" || exit 1
