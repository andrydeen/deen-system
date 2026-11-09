#!/usr/bin/env bash
. "$(dirname "$0")/helpers.sh"

# old_touch <file> <minutes> — set mtime that many minutes in the past.
old_touch() {
  local stamp
  stamp=$(date -v-"$2"M +%Y%m%d%H%M 2>/dev/null) || stamp=$(date -d "-$2 min" +%Y%m%d%H%M)
  touch -t "$stamp" "$1"
}

# mk_run <T-00N> <status> — fabricates a run dir the way dispatch leaves it.
mk_run() {
  local run="$HUB_DIR/.runs/$1"
  mkdir -p "$run" "$HUB_DIR/demo proj"
  echo "$2" > "$run/status"
  echo "$HUB_DIR/demo proj" > "$run/project"
}
live() { echo "$$" > "$HUB_DIR/.runs/$1/pid"; echo "$$" > "$HUB_DIR/.runs/$1/claude-pid"; }

new_ticket() { hub new --project demo --title "Watched" <<< 'brief' >/dev/null || fail "new"; }
last_log() { tail -n 1 "$HUB_DIR/.runs/events.log"; }

test_watch_stall() {
  setup_projects; new_ticket
  mk_run T-001 running; live T-001
  : > "$HUB_DIR/.runs/T-001/events.jsonl"; old_touch "$HUB_DIR/.runs/T-001/events.jsonl" 20
  local out; out="$(hub watch)" || fail "watch"
  echo "$out" | grep -q '⚠ stall T-001 no output for' || fail "no stall line: $out"
  assert_eq stall "$(hub ticket get T-001 flag)" "flag"
  grep -q '^- ⚠ T-001' "$HUB_DIR/INDEX.md" || fail "INDEX line"
  last_log | grep -q '⚠ stall T-001' || fail "events.log: $(last_log)"
  hub board --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "⚠stall" in d[0]["flags"], d' || fail "board flags"
  local n; n=$(wc -l < "$HUB_DIR/.runs/events.log")
  out="$(hub watch)" || fail "watch 2"
  echo "$out" | grep -q '⚠ stall T-001' || fail "second pass should reprint"
  assert_eq "$n" "$(wc -l < "$HUB_DIR/.runs/events.log")" "no new log line"
}

test_watch_loop() {
  setup_projects; new_ticket
  mk_run T-001 running; live T-001
  cp "$TESTS_DIR/fixtures/events-loop.jsonl" "$HUB_DIR/.runs/T-001/events.jsonl"
  local out; out="$(hub watch)" || fail "watch"
  echo "$out" | grep '⚠ loop T-001' | grep -q '/p/a.xml' || fail "loop line: $out"
  assert_eq loop "$(hub ticket get T-001 flag)" "flag"
}

test_watch_dead() {
  setup_projects; new_ticket
  mk_run T-001 running
  hub set T-001 status running >/dev/null
  echo 999999 > "$HUB_DIR/.runs/T-001/pid"
  mkdir -p "$HUB_DIR/.runs/.slots/1"; echo 999999 > "$HUB_DIR/.runs/.slots/1/pid"
  echo 1 > "$HUB_DIR/.runs/T-001/slot"
  local out; out="$(hub watch)" || fail "watch"
  echo "$out" | grep -q '⚠ dead T-001 pid 999999 not alive' || fail "dead line: $out"
  assert_eq failed "$(cat "$HUB_DIR/.runs/T-001/status")" "run status"
  assert_eq failed "$(hub ticket get T-001 status)" "ticket status"
  [ -e "$HUB_DIR/.runs/.slots/1" ] && fail "slot not released"
  assert_grep 'failed T-001 worker died' "$HUB_DIR/.runs/events.log"
  assert_eq dead "$(hub ticket get T-001 flag)" "flag kept"
  [ -e "$HUB_DIR/.runs/T-001/pid" ] && fail "pid should be gone"
  out="$(hub watch)"; [ -z "$out" ] || fail "finished ticket skipped: $out"
}

test_watch_budget() {
  setup_projects; new_ticket
  mk_run T-001 running; live T-001
  echo '{"type":"result","subtype":"success","result":"x","total_cost_usd":9.0}' > "$HUB_DIR/.runs/T-001/events.jsonl"
  local out; out="$(hub watch)" || fail "watch"
  echo "$out" | grep -q '⚠ budget T-001 \$9.00 ≥ \$8' || fail "budget line: $out"
  assert_eq budget "$(hub ticket get T-001 flag)" "flag"
}

test_watch_healthy_clears() {
  setup_projects; new_ticket
  mk_run T-001 running; live T-001
  cp "$TESTS_DIR/fixtures/events-ready.jsonl" "$HUB_DIR/.runs/T-001/events.jsonl"
  echo "working" > "$HUB_DIR/demo proj/progress.log"
  hub set T-001 flag stall >/dev/null
  local out; out="$(hub watch)" || fail "watch"
  echo "$out" | grep -q 'T-001' && fail "healthy printed: $out"
  assert_eq "" "$(hub ticket get T-001 flag)" "flag cleared"
  grep 'T-001' "$HUB_DIR/INDEX.md" | grep -q '⚠' && fail "INDEX still flagged"
  return 0
}

test_watch_skips_finished() {
  setup_projects; new_ticket
  mk_run T-001 "exited 0"
  local out; out="$(hub watch)" || fail "watch"
  [ -z "$out" ] || fail "expected no output: $out"
  assert_eq "" "$(hub ticket get T-001 flag)" "flag"
}

for t in test_watch_stall test_watch_loop test_watch_dead test_watch_budget test_watch_healthy_clears test_watch_skips_finished; do
  ( "$t" ) || exit 1
done
echo "PASS ${0##*/}"
