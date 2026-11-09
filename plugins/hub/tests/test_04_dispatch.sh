. "$(dirname "$0")/helpers.sh"

ALL_TMP=""
cleanup() {
  pkill -f "$TESTS_DIR/fake-claude" 2>/dev/null
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

last_line() { tail -n 1 "$HUB_DIR/.runs/events.log"; }

test_dispatch_none() {
  setup_projects
  hub new --project demo --title "A" <<< 'brief' >/dev/null || fail "new"
  hub dispatch T-001 --wait || fail "dispatch exit"
  local r="$HUB_DIR/.runs/T-001"
  assert_file "$r/session-id"; assert_file "$r/events.jsonl"; assert_file "$r/report.md"
  assert_eq ready "$(hub ticket get T-001 status)" "status"
  last_line | grep -Eq 'ready T-001' || fail "events.log last line: $(last_line)"
  assert_eq 1 "$(log_py 'print(len(E))')" "one invocation"
  log_py 'a=E[0]["argv"]; assert a[a.index("--agent")+1]=="hub-worker"
assert a[a.index("--permission-mode")+1]=="auto"
assert a[a.index("--allowedTools")+1]=="Write,Edit,Read,Glob,Grep"
assert a[a.index("--max-turns")+1]=="150"
assert a[a.index("--max-budget-usd")+1]=="8"
assert "--session-id" in a' || fail "argv"
  assert_eq "$(real "$HUB_DIR/demo proj")" "$(log_py 'print(E[0]["cwd"])')" "cwd"
  [ ! -e "$HUB_DIR/demo proj/.claude/worktrees" ] || fail "no worktrees for none"
  [ ! -e "$r/pid" ] || fail "pid removed"
  [ -z "$(ls "$HUB_DIR/.runs/.slots")" ] || fail "slot released"
}

test_dispatch_path_with_spaces() {
  setup_projects
  hub new --project gitproj --title "G" <<< 'brief' >/dev/null || fail "new"
  hub dispatch T-001 --wait || fail "dispatch"
  local wt="$HUB_DIR/git proj/.claude/worktrees/T-001"
  [ -d "$wt" ] || fail "worktree missing"
  assert_eq "hub/T-001" "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" "branch"
  assert_eq "$(real "$wt")" "$(log_py 'print(E[0]["cwd"])')" "cwd is worktree"
  assert_eq "$wt" "$(cat "$HUB_DIR/.runs/T-001/worktree")" "worktree file"
}

test_dispatch_prompt_verbatim() {
  setup_projects
  local b="it's \"quoted\" \$HOME \`tick\`
second line"
  hub new --project demo --title "P" <<< "$b" >/dev/null || fail "new"
  hub dispatch T-001 --wait || fail "dispatch"
  assert_eq "$b" "$(log_py 'print(E[0]["argv"][E[0]["argv"].index("-p")+1], end="")')" "prompt"
}

test_dispatch_unknown_report() {
  setup_projects
  hub new --project demo --title "U" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_RESULT="done, all good" hub dispatch T-001 --wait || fail "dispatch"
  assert_eq unknown-report "$(hub ticket get T-001 status)" "status"
}

test_dispatch_denied() {
  setup_projects
  hub new --project demo --title "D" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_EVENTS="$TESTS_DIR/fixtures/events-interrupted.jsonl" hub dispatch T-001 --wait || fail "dispatch"
  assert_eq blocked "$(hub ticket get T-001 status)" "status"
  assert_grep "permission denied: Write" "$(ls "$HUB_DIR"/tickets/T-001-*.md)"
  last_line | grep -q 'blocked T-001 permission denied: Write$' || fail "events.log note: $(last_line)"
  last_line | grep -Eq 'blocked T-00' || fail "events.log: $(last_line)"
}

test_dispatch_reclaims_stale_slot() {
  setup_projects
  local n
  for n in 1 2 3 4; do mkdir -p "$HUB_DIR/.runs/.slots/$n"; echo 999999 > "$HUB_DIR/.runs/.slots/$n/pid"; done
  hub new --project demo --title "S" <<< 'b' >/dev/null || fail "new"
  hub dispatch T-001 --wait || fail "dispatch"
  assert_eq ready "$(hub ticket get T-001 status)" "status"
  grep -q queued "$HUB_DIR/.runs/T-001/status" && fail "was queued"
  return 0
}

test_dispatch_queue() {
  setup_projects
  export HUB_MAX_WORKERS=1 FAKE_CLAUDE_SLEEP=3 HUB_QUEUE_POLL_S=0.5
  hub new --project demo --title "Q1" <<< 'b' >/dev/null || fail "new1"
  hub new --project demo --title "Q2" <<< 'b' >/dev/null || fail "new2"
  hub dispatch T-001 | grep -Eq '^dispatched T-001 round 1 pid [0-9]+$' || fail "dispatch output"
  local i
  for i in $(seq 1 50); do [ "$(cat "$HUB_DIR/.runs/T-001/status" 2>/dev/null)" = running ] && break; sleep 0.1; done
  assert_eq running "$(cat "$HUB_DIR/.runs/T-001/status")" "T-001 running"
  assert_eq T-001 "$(cat "$HUB_DIR/.runs/.slots/1/ticket")" "T-001 holds slot 1"
  hub dispatch T-002 >/dev/null || fail "dispatch 2"
  for i in $(seq 1 20); do [ "$(cat "$HUB_DIR/.runs/T-002/status" 2>/dev/null)" = queued ] && break; sleep 0.1; done
  assert_eq queued "$(cat "$HUB_DIR/.runs/T-002/status")" "second queued"
  for i in $(seq 1 100); do
    [ "$(hub ticket get T-001 status)" = ready ] && [ "$(hub ticket get T-002 status)" = ready ] && break
    sleep 0.1
  done
  assert_eq ready "$(hub ticket get T-001 status)" "T-001 ready"
  assert_eq ready "$(hub ticket get T-002 status)" "T-002 ready"
  unset HUB_MAX_WORKERS FAKE_CLAUDE_SLEEP HUB_QUEUE_POLL_S
}

test_dispatch_retry() {
  setup_projects
  hub new --project demo --title "R" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_FAIL_FIRST=1 HUB_RETRY_BASE_S=0 hub dispatch T-001 --wait || fail "dispatch"
  assert_eq ready "$(hub ticket get T-001 status)" "status"
  assert_eq 2 "$(log_py 'print(len(E))')" "two invocations"
  assert_eq 1 "$(log_py 'print(int("--resume" in E[1]["argv"] and "--session-id" in E[0]["argv"]))')" "resume on retry"
}

test_dispatch_pid_alive_while_queued() {
  setup_projects
  export HUB_MAX_WORKERS=1 FAKE_CLAUDE_SLEEP=3 HUB_QUEUE_POLL_S=0.5
  hub new --project demo --title "A1" <<< 'b' >/dev/null || fail "new1"
  hub new --project demo --title "A2" <<< 'b' >/dev/null || fail "new2"
  hub dispatch T-001 >/dev/null || fail "dispatch 1"
  local i
  for i in $(seq 1 50); do [ "$(cat "$HUB_DIR/.runs/T-001/status" 2>/dev/null)" = running ] && break; sleep 0.1; done
  hub dispatch T-002 >/dev/null || fail "dispatch 2"
  for i in $(seq 1 30); do [ "$(cat "$HUB_DIR/.runs/T-002/status" 2>/dev/null)" = queued ] && break; sleep 0.1; done
  assert_eq queued "$(cat "$HUB_DIR/.runs/T-002/status")" "queued"
  kill -0 "$(cat "$HUB_DIR/.runs/T-002/pid")" 2>/dev/null || fail "queued pid is dead"
  local out
  out=$(hub dispatch T-002 2>&1) && fail "second dispatch must fail"
  echo "$out" | grep -q "already running" || fail "message: $out"
  for i in $(seq 1 150); do
    [ "$(hub ticket get T-001 status)" = ready ] && [ "$(hub ticket get T-002 status)" = ready ] && break
    sleep 0.1
  done
  assert_eq ready "$(hub ticket get T-001 status)" "T-001 ready"
  assert_eq ready "$(hub ticket get T-002 status)" "T-002 ready"
  unset HUB_MAX_WORKERS FAKE_CLAUDE_SLEEP HUB_QUEUE_POLL_S
}

test_dispatch_no_retry_on_max_turns() {
  setup_projects
  printf '%s\n' '{"type":"result","subtype":"error_max_turns","result":null,"duration_ms":523,"total_cost_usd":0.5}' > "$TMP_ROOT/mt.jsonl"
  hub new --project demo --title "M" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_STDERR="429 rate limit" FAKE_CLAUDE_EVENTS="$TMP_ROOT/mt.jsonl" FAKE_CLAUDE_EXIT=1 HUB_RETRY_BASE_S=0 hub dispatch T-001 --wait
  assert_eq 1 "$(log_py 'print(len(E))')" "no retry"
  assert_eq unknown-report "$(hub ticket get T-001 status)" "status"
}

test_worker_sigint_default() {
  setup_projects
  . "$PLUGIN_ROOT/scripts/lib/dispatch.sh"
  local p
  ( cd "$TMP_ROOT" && hub_exec_worker python3 -c 'import os,signal; print(signal.getsignal(signal.SIGINT)!=signal.SIG_IGN, os.getpid())' > "$TMP_ROOT/sig" ) >/dev/null 2>&1 &
  p=$!
  wait "$p"
  assert_eq "True $p" "$(cat "$TMP_ROOT/sig")" "wrapper restores SIGINT and keeps pid"
  ( python3 -c 'import signal; print(signal.getsignal(signal.SIGINT)!=signal.SIG_IGN)' > "$TMP_ROOT/sig2" ) >/dev/null 2>&1 &
  wait
  assert_eq False "$(cat "$TMP_ROOT/sig2")" "control: ignored without wrapper"
}

test_dispatch_none
test_dispatch_pid_alive_while_queued
test_dispatch_no_retry_on_max_turns
test_worker_sigint_default
test_dispatch_path_with_spaces
test_dispatch_prompt_verbatim
test_dispatch_unknown_report
test_dispatch_denied
test_dispatch_reclaims_stale_slot
test_dispatch_queue
test_dispatch_retry
echo "PASS $0"
