. "$(dirname "$0")/helpers.sh"

R() { echo "$HUB_DIR/.runs/T-001"; }

# wait_for <seconds> <description> <command...> — polls until the command succeeds.
wait_for() {
  local secs="$1" what="$2" i=0
  shift 2
  while ! "$@" >/dev/null 2>&1; do
    i=$((i + 1)); [ "$i" -le $((secs * 5)) ] || fail "timeout waiting for $what"
    sleep 0.2
  done
}
ticket_is() { [ "$(hub ticket get T-001 status)" = "$1" ]; }
fake_running() {
  local p; p=$(cat "$(R)/pid" 2>/dev/null)
  [ "$(cat "$(R)/status" 2>/dev/null)" = running ] && [ -n "$p" ] \
    && pgrep -f "$TESTS_DIR/claude" | grep -qx "$p"
}
no_fake() { ! pgrep -f "$TESTS_DIR/claude"; }
t2_queued() { [ "$(cat "$HUB_DIR/.runs/T-002/status" 2>/dev/null)" = queued ]; }
first_seen() { grep -qs first "$(R)/briefs.log" "$(R)"/pending/*.md; }
start_slow() {
  hub new --project demo --title "S" <<< 'brief' >/dev/null || fail "new"
  FAKE_CLAUDE_SLEEP=20 hub dispatch T-001 >/dev/null || fail "dispatch"
  wait_for 10 "running fake" fake_running
}

test_send_idle() {
  setup_projects
  hub new --project demo --title "I" <<< 'brief' >/dev/null || fail "new"
  hub dispatch T-001 --wait || fail "dispatch"
  hub send T-001 "more" >/dev/null || fail "send"
  wait_for 10 "ready again" ticket_is ready
  wait_for 10 "pid cleanup" test ! -e "$(R)/pid"
  assert_eq 2 "$(log_py 'print(len(E))')" "two invocations"
  local sid; sid=$(cat "$(R)/session-id")
  assert_eq "$sid" "$(log_py 'a=E[1]["argv"]; print(a[a.index("--resume")+1])')" "resume id"
  log_py 'assert "--session-id" not in E[1]["argv"]' || fail "no --session-id"
  log_py 'a=E[1]["argv"]; p=a[a.index("-p")+1]; assert p.startswith("Follow-up from the human:") and "more" in p' || fail "prompt"
  assert_grep 'more' "$(R)/briefs.log"
  assert_file "$(R)/prompt-2.md"
  grep -q 'sent: more' "$HUB_DIR"/tickets/T-001-*.md || fail "ticket log lacks sent:"
}

test_send_after_manual_marker() {
  setup_projects
  hub new --project demo --title "M" <<< 'brief' >/dev/null || fail "new"
  hub dispatch T-001 --wait || fail "dispatch"
  touch "$(R)/interrupted"
  hub send T-001 "more" >/dev/null || fail "send"
  wait_for 10 "ready again" ticket_is ready
  wait_for 10 "pid cleanup" test ! -e "$(R)/pid"
  assert_eq 2 "$(log_py 'print(len(E))')" "two invocations"
  assert_eq ready "$(hub ticket get T-001 status)" "status"
}

test_send_undispatched() {
  setup_projects
  hub new --project demo --title "U" <<< 'brief' >/dev/null || fail "new"
  hub send T-001 "x" >/dev/null 2>&1 && fail "send before dispatch must fail"
  [ ! -s "$FAKE_CLAUDE_LOG" ] || fail "no worker may start"
}

test_send_interrupts() {
  setup_projects
  start_slow
  local fp; fp=$(cat "$(R)/pid")
  export FAKE_CLAUDE_SLEEP=0
  hub send T-001 "change course" >/dev/null || fail "send"
  kill -0 "$fp" 2>/dev/null && fail "first fake still alive"
  grep -q interrupted "$HUB_DIR"/tickets/T-001-*.md || fail "ticket log lacks interrupted"
  wait_for 10 "ready" ticket_is ready
  assert_eq 2 "$(log_py 'print(len(E))')" "two invocations"
  assert_eq "running running ready " "$(awk '{printf "%s ", $2}' "$HUB_DIR/.runs/events.log")" "no report between rounds"
  log_py 'a=E[1]["argv"]; p=a[a.index("-p")+1]; assert p.startswith("Interrupted by the human.") and "change course" in p' || fail "prompt"
  assert_grep 'change course' "$(R)/briefs.log"
  unset FAKE_CLAUDE_SLEEP
}

test_send_queues_during_restart() {
  setup_projects
  start_slow
  export FAKE_CLAUDE_SLEEP=0
  hub send T-001 "first" >/dev/null & local a=$!
  wait_for 5 "first send queued" first_seen
  hub send T-001 "second" >/dev/null & local b=$!
  wait "$a" "$b"
  wait_for 15 "ready" ticket_is ready
  wait_for 10 "pid cleanup" test ! -e "$(R)/pid"
  assert_eq 2 "$(log_py 'print(len(E))')" "exactly two invocations"
  log_py 'a=E[1]["argv"]; p=a[a.index("-p")+1]; assert 0 <= p.index("first") < p.index("second")' || fail "order"
  unset FAKE_CLAUDE_SLEEP
}

test_stop() {
  setup_projects
  start_slow
  hub stop T-001 >/dev/null || fail "stop"
  wait_for 5 "no fake" no_fake
  assert_eq stopped "$(hub ticket get T-001 status)" "ticket status"
  assert_eq stopped "$(cat "$(R)/status")" "run status"
  last_line | grep -Eq 'stopped T-001' || fail "events.log last line: $(last_line)"
  [ -z "$(ls "$HUB_DIR/.runs/.slots"/*/pid 2>/dev/null)" ] || fail "slot not released"
  [ ! -e "$(R)/pid" ] || fail "pid file remains"
  hub stop T-001 | grep -q 'was not running' || fail "idle stop message"
}

test_stop_queued() {
  setup_projects
  export HUB_MAX_WORKERS=1 HUB_QUEUE_POLL_S=0.5 FAKE_CLAUDE_SLEEP=5
  hub new --project demo --title "A" <<< 'a' >/dev/null || fail "new"
  hub new --project demo --title "B" <<< 'b' >/dev/null || fail "new"
  hub dispatch T-001 >/dev/null || fail "dispatch 1"
  wait_for 10 "T-001 running" fake_running
  hub dispatch T-002 >/dev/null || fail "dispatch 2"
  wait_for 10 "T-002 queued" t2_queued
  local t0=$SECONDS
  hub stop T-002 >/dev/null || fail "stop T-002"
  [ $((SECONDS - t0)) -le 3 ] || fail "stop of queued round took too long"
  assert_eq stopped "$(hub ticket get T-002 status)" "T-002 status"
  [ ! -e "$HUB_DIR/.runs/T-002/pid" ] || fail "T-002 pid remains"
  assert_eq 1 "$(ls "$HUB_DIR/.runs/.slots" | wc -l | tr -d ' ')" "only T-001 slot"
  assert_eq T-001 "$(cat "$HUB_DIR/.runs/.slots"/*/ticket)" "slot owner"
  hub stop T-001 >/dev/null || fail "stop T-001"
  [ -z "$(ls "$HUB_DIR/.runs/.slots")" ] || fail "T-001 slot not released"
  unset HUB_MAX_WORKERS HUB_QUEUE_POLL_S FAKE_CLAUDE_SLEEP
}

last_line() { tail -n 1 "$HUB_DIR/.runs/events.log"; }

test_send_idle
test_send_after_manual_marker
test_send_undispatched
test_send_interrupts
test_send_queues_during_restart
test_stop
test_stop_queued
echo "PASS $0"
