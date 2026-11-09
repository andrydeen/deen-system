#!/usr/bin/env bash
. "$(dirname "$0")/helpers.sh"

setup_board() {
  setup_projects
  hub new --project demo --files out.txt --title "Ready one" <<< 'brief a' >/dev/null || fail "new 1"
  hub new --project demo --files out.txt --title "Stalled one" <<< 'brief b' >/dev/null || fail "new 2"
  FAKE_CLAUDE_EVENTS="$TESTS_DIR/fixtures/events-ready.jsonl" hub dispatch T-001 --wait || fail "dispatch"
  hub set T-002 flag stall >/dev/null || fail "set flag"
}

test_board_text() {
  setup_board
  local out; out="$(hub board)" || fail "board"
  echo "$out" | head -n 1 | grep -q 'NOW' || fail "header NOW"
  echo "$out" | head -n 1 | grep -q 'FLAGS' || fail "header FLAGS"
  echo "$out" | sed -n 2p | grep -q 'T-002' || fail "flagged first: $out"
  echo "$out" | sed -n 2p | grep -q '⚠stall' || fail "flag shown"
  echo "$out" | grep 'T-001' | grep -q 'ready' || fail "ready row"
  echo "$out" | grep 'T-001' | grep -q 'Edit /p/a.xml' || fail "now column: $out"
}

test_board_json() {
  setup_board
  hub board --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d,list); assert d[1]["status"]=="ready" and d[1]["cost_usd"]==0.42, d' || fail "json"
  assert_file "$HUB_DIR/board.json"
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "generated" in d and len(d["rows"])==2' "$HUB_DIR/board.json" || fail "board.json shape"
}

test_board_cost_all_rounds() {
  setup_board
  hub send T-001 "again" >/dev/null || fail "send"
  local i
  for i in $(seq 1 50); do [ ! -e "$HUB_DIR/.runs/T-001/pid" ] && [ "$(hub ticket get T-001 status)" = ready ] && break; sleep 0.2; done
  assert_eq 2 "$(log_py 'print(len(E))')" "two rounds"
  hub board --json | python3 -c 'import json,sys; d={r["id"]: r for r in json.load(sys.stdin)}; assert d["T-001"]["cost_usd"]==0.84, d["T-001"]' || fail "board cost is the sum"
  hub show T-001 | grep -qx 'cost_usd: 0.84' || fail "show cost"
}

test_board_all() {
  setup_board
  hub set T-001 status done >/dev/null || fail "set done"
  hub board | grep -q 'T-001' && fail "done should be hidden"
  hub board --all | grep -q 'T-001' || fail "--all should include done"
  return 0
}

test_board_empty() {
  setup_projects
  hub board | grep -q '(no tickets)' || fail "empty board"
}

test_show() {
  setup_board
  local out; out="$(hub show T-001)" || fail "show"
  for p in '## Ticket' '## Brief' '## Steering' '## Progress' '## Tool calls' '## Report' '## Run' 'Status: ready' 'Files:' 'exited 0' 'Read /p/a.xml'; do
    echo "$out" | grep -q -- "$p" || fail "show lacks [$p]"
  done
}

test_progress_in_run_dir() {
  setup_board
  sleep 1
  # a stale progress.log in the project dir must lose to the run dir one
  printf '09:00  stale cwd line\n' > "$HUB_DIR/demo proj/progress.log"
  printf '10:01  start\n10:02  checking run dir\n' > "$HUB_DIR/.runs/T-001/progress.log"
  hub board | grep 'T-001' | grep -q '10:02 checking run dir' || fail "board NOW lacks run-dir progress: $(hub board)"
  hub show T-001 | grep -q '10:02  checking run dir' || fail "show lacks run-dir progress"
}

test_events() {
  setup_board
  assert_eq 2 "$(hub events --since 2 --no-follow | wc -l | tr -d ' ')" "line count"
  assert_eq "$(tail -n 2 "$HUB_DIR/.runs/events.log")" "$(hub events --since 2 --no-follow)" "last two lines"
}

for t in test_board_text test_board_json test_board_cost_all_rounds test_board_all test_board_empty test_show test_progress_in_run_dir test_events; do
  ( "$t" ) || exit 1
done
echo "PASS ${0##*/}"
