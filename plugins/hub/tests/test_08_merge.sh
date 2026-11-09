. "$(dirname "$0")/helpers.sh"

STUB_PID=""
stub_cleanup() { [ -n "$STUB_PID" ] && { kill "$STUB_PID" 2>/dev/null; wait "$STUB_PID" 2>/dev/null; }; STUB_PID=""; }
trap 'stub_cleanup; cleanup' EXIT

# setup_projects plus: demo proj is a git repo too, with a tracked keep.txt.
setup_both() {
  setup_projects
  ( cd "$HUB_DIR/demo proj" && git init -q -b main && git config user.email t@t && git config user.name t \
    && echo k > keep.txt && git add keep.txt && git commit -q -m init ) || fail "git init demo"
}

events_last() { tail -n 1 "$HUB_DIR/.runs/events.log"; }
tfile() { ls "$HUB_DIR"/tickets/"$1"-*.md; }

test_eval_green_red() {
  setup_both
  hub new --project demo --title "E" <<< 'b' >/dev/null || fail "new"
  hub ticket eval-set T-001 "test -f out.txt" || fail "eval-set"
  FAKE_CLAUDE_TOUCH=out.txt hub dispatch T-001 --wait || fail "dispatch"
  local out rc=0
  out=$(hub eval T-001) || rc=$?
  assert_eq 0 "$rc" "green exit"
  assert_eq green "$(echo "$out" | head -n 1)" "green"
  assert_eq green "$(hub ticket get T-001 eval)" "eval field"
  hub ticket eval-set T-001 "false" || fail "eval-set 2"
  rc=0; out=$(hub eval T-001) || rc=$?
  assert_eq 1 "$rc" "red exit"
  assert_eq red "$(echo "$out" | head -n 1)" "red"
  assert_eq red "$(hub ticket get T-001 eval)" "eval field red"
  assert_grep 'eval: red' "$(tfile T-001)"
  hub new --project demo --title "NoBlock" <<< 'b' >/dev/null || fail "new2"
  rc=0; out=$(hub eval T-002) || rc=$?
  assert_eq 0 "$rc" "n/a exit"
  assert_eq "n/a" "$out" "n/a"
  assert_eq "n/a" "$(hub ticket get T-002 eval)" "eval n/a field"
  # spec dir takes precedence
  mkdir -p "$TMP_ROOT/spec dir"
  printf '# eval\n\n```check\ntest -f keep.txt\n```\n' > "$TMP_ROOT/spec dir/eval.md"
  hub new --project demo --title "Spec" --spec "$TMP_ROOT/spec dir" <<< 'b' >/dev/null || fail "new3"
  rc=0; out=$(hub eval T-003) || rc=$?
  assert_eq 0 "$rc" "spec eval exit"
  assert_eq green "$(echo "$out" | head -n 1)" "spec eval green"
}

test_eval_timeout() {
  setup_both
  hub new --project demo --title "T" <<< 'b' >/dev/null || fail "new"
  hub ticket eval-set T-001 "sleep 5" || fail "eval-set"
  local out rc=0 t0 t1
  t0=$(date +%s)
  out=$(HUB_EVAL_TIMEOUT_S=1 hub eval T-001) || rc=$?
  t1=$(date +%s)
  assert_eq 1 "$rc" "timeout exit"
  assert_eq red "$(echo "$out" | head -n 1)" "red"
  echo "$out" | grep -q 'timed out' || fail "no timed out in: $out"
  [ $((t1 - t0)) -le 4 ] || fail "took $((t1 - t0)) s"
}

test_propose() {
  setup_both
  hub new --project demo --title "P" <<< 'b' >/dev/null || fail "new"
  local rc=0
  hub propose T-001 "commit and merge" --no-telegram 2>/dev/null || rc=$?
  assert_eq 1 "$rc" "not ready refused"
  hub ticket set T-001 status ready
  local out
  out=$(hub propose T-001 "commit and merge" --no-telegram) || fail "propose"
  assert_eq 1 "$(echo "$out" | wc -l | tr -d ' ')" "one stdout line"
  echo "$out" | grep -q '\[T-001-1\]' || fail "id missing: $out"
  echo "$out" | grep -q 'Reply: yes T-1 · approve T-001-1 · reject T-001-1' || fail "reply text: $out"
  local f="$APPROVALS_DIR/T-001-1.md"
  assert_file "$f"
  assert_grep '^status: pending$' "$f"
  assert_grep '^id: T-001-1$' "$f"
  assert_grep '^ticket: T-001$' "$f"
  assert_grep '^requested_by: hub-router$' "$f"
  assert_grep '^hub merge T-001$' "$f"
  assert_grep '^commit and merge$' "$f"
  assert_grep 'Merge ticket T-001 \(P\) into main\.' "$f"
  assert_grep 'proposed T-001-1' "$(tfile T-001)"
  out=$(hub propose T-001 "again" --push --no-telegram) || fail "propose 2"
  assert_file "$APPROVALS_DIR/T-001-2.md"
  assert_grep '^hub merge T-001 --push$' "$APPROVALS_DIR/T-001-2.md"
  assert_grep 'and push\.' "$APPROVALS_DIR/T-001-2.md"
  # long recommendation is truncated to 100 words
  local long w
  long=$(python3 -c 'print(" ".join("w%d" % i for i in range(300)))')
  out=$(hub propose T-001 "$long" --no-telegram) || fail "propose long"
  w=$(echo "$out" | wc -w | tr -d ' ')
  [ "$w" -le 120 ] || fail "too many words: $w"
  echo "$out" | grep -q 'w99' || fail "word 100 missing"
  echo "$out" | grep -q 'w100' && fail "word 101 present"
  return 0
}

test_propose_requires_ready() {
  setup_both
  hub new --project demo --title "R" <<< 'b' >/dev/null || fail "new"
  local rc=0
  hub propose T-001 "x" --no-telegram 2>/dev/null || rc=$?
  assert_eq 1 "$rc" "exit"
  [ -z "$(ls "$APPROVALS_DIR")" ] || fail "record written"
}

test_propose_telegram() {
  setup_both
  hub new --project demo --title "Tg" <<< 'b' >/dev/null || fail "new"
  hub ticket set T-001 status ready
  cat > "$TMP_ROOT/stub.py" <<'PY'
import http.server, sys
portfile, bodyfile = sys.argv[1], sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        with open(bodyfile, "w") as f:
            f.write(self.path + "\n" + self.rfile.read(n).decode())
        self.send_response(401 if "BAD" in self.path else 200)
        self.end_headers()
        self.wfile.write(b"{}")
    def log_message(self, *a):
        pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
with open(portfile, "w") as f:
    f.write(str(s.server_address[1]))
s.serve_forever()
PY
  python3 "$TMP_ROOT/stub.py" "$TMP_ROOT/port" "$TMP_ROOT/body" &
  STUB_PID=$!
  local i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [ -s "$TMP_ROOT/port" ] && break
    sleep 0.2
  done
  [ -s "$TMP_ROOT/port" ] || fail "stub did not start"
  local dummy="SECRET-TOKEN-XYZ"
  printf 'TELEGRAM_BOT_%s="%s"\n' TOKEN "$dummy" > "$TMP_ROOT/tg.env"
  printf -- '---\ntelegram_chat_id: "123"\n---\n' > "$APPROVALS_DIR/config.md"
  local out err
  out=$(TELEGRAM_ENV_FILE="$TMP_ROOT/tg.env" HUB_TELEGRAM_API="http://127.0.0.1:$(cat "$TMP_ROOT/port")" \
    hub propose T-001 "ship it" 2>"$TMP_ROOT/err") || fail "propose"
  err=$(cat "$TMP_ROOT/err")
  assert_file "$TMP_ROOT/body"
  assert_grep '^/botSECRET-TOKEN-XYZ/sendMessage$' "$TMP_ROOT/body"
  assert_grep 'chat_id=123' "$TMP_ROOT/body"
  assert_grep 'text=.*T-001-1' "$TMP_ROOT/body"
  stub_cleanup
  local f
  for f in "$(tfile T-001)" "$HUB_DIR/.runs/events.log" "$APPROVALS_DIR/T-001-1.md" "$HUB_DIR/INDEX.md"; do
    grep -q 'SECRET-TOKEN' "$f" && fail "token leaked in $f"
  done
  echo "$out$err" | grep -q 'SECRET-TOKEN' && fail "token leaked in output"
  # not configured: no token file
  out=$(TELEGRAM_ENV_FILE="$TMP_ROOT/none.env" hub propose T-001 "again" 2>&1 >"$TMP_ROOT/o1") || fail "propose unconfigured"
  echo "$out" | grep -q 'telegram: not configured' || fail "no not-configured message: $out"
  # send failure: nothing listens on port 1
  out=$(TELEGRAM_ENV_FILE="$TMP_ROOT/tg.env" HUB_TELEGRAM_API="http://127.0.0.1:1" \
    hub propose T-001 "third" 2>&1 >"$TMP_ROOT/o2") || fail "propose send fail exit"
  echo "$out" | grep -q 'telegram: send failed' || fail "no send failed message: $out"
  echo "$out" | grep -q 'SECRET-TOKEN' && fail "token leaked in failure output"
  # API rejects (401): curl -f makes it a failure, token still hidden
  printf 'TELEGRAM_BOT_%s="%s"\n' TOKEN "BAD-TOKEN" > "$TMP_ROOT/bad.env"
  python3 "$TMP_ROOT/stub.py" "$TMP_ROOT/port2" "$TMP_ROOT/body2" &
  STUB_PID=$!
  for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    [ -s "$TMP_ROOT/port2" ] && break
    sleep 0.2
  done
  out=$(TELEGRAM_ENV_FILE="$TMP_ROOT/bad.env" HUB_TELEGRAM_API="http://127.0.0.1:$(cat "$TMP_ROOT/port2")" \
    hub propose T-001 "fourth" 2>&1 >"$TMP_ROOT/o3") || fail "propose 401 exit"
  stub_cleanup
  echo "$out" | grep -q 'telegram: send failed' || fail "401 not reported: $out"
  echo "$out" | grep -q 'BAD-TOKEN' && fail "token leaked on 401"
  return 0
}

test_merge_worktree() {
  setup_both
  hub new --project gitproj --title "W" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_TOUCH=new.txt hub dispatch T-001 --wait || fail "dispatch"
  local repo="$HUB_DIR/git proj" wt="$HUB_DIR/git proj/.claude/worktrees/T-001"
  [ -f "$wt/new.txt" ] || fail "worker file missing"
  hub merge T-001 >"$TMP_ROOT/merge.out" || fail "merge"
  assert_eq touched "$(cat "$repo/new.txt")" "file on main"
  [ ! -e "$wt" ] || fail "worktree still there"
  git -C "$repo" show-ref --verify --quiet refs/heads/hub/T-001 && fail "branch remains"
  assert_eq done "$(hub ticket get T-001 status)" "status"
  [ ! -e "$HUB_DIR/.runs/T-001/worktree" ] || fail "worktree file remains"
  assert_eq main "$(git -C "$repo" rev-parse --abbrev-ref HEAD)" "still on main"
  git -C "$repo" log --format=%s -n 1 | grep -q '^merge hub/T-001: W$' || fail "merge commit msg"
  events_last | grep -q ' done T-001$' || fail "events.log: $(events_last)"
  assert_grep 'merged' "$(tfile T-001)"
}

test_merge_conflict() {
  setup_both
  hub new --project gitproj --title "C" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_TOUCH=f hub dispatch T-001 --wait || fail "dispatch"
  local repo="$HUB_DIR/git proj" wt="$HUB_DIR/git proj/.claude/worktrees/T-001"
  ( cd "$repo" && echo other > f && git commit -q -am "main change" ) || fail "main commit"
  local before out rc=0
  before=$(git -C "$repo" rev-parse main)
  out=$(hub merge T-001 2>&1) || rc=$?
  assert_eq 2 "$rc" "exit"
  assert_eq conflict "$(hub ticket get T-001 status)" "status"
  assert_eq "$before" "$(git -C "$repo" rev-parse main)" "main unchanged"
  [ -d "$wt" ] || fail "worktree gone"
  echo "$out" | grep -q 'conflict merging main into hub/T-001: f$' || fail "message: $out"
  assert_grep 'conflict.*f' "$(tfile T-001)"
  assert_eq "" "$(git -C "$wt" status --porcelain | grep '^U' )" "merge aborted"
}

test_merge_reeval_red() {
  setup_both
  hub new --project gitproj --title "Red" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_TOUCH=new.txt hub dispatch T-001 --wait || fail "dispatch"
  hub ticket eval-set T-001 "false"
  local repo="$HUB_DIR/git proj" before rc=0
  before=$(git -C "$repo" rev-parse main)
  hub merge T-001 >"$TMP_ROOT/o" 2>&1 || rc=$?
  assert_eq 1 "$rc" "exit"
  assert_eq "$before" "$(git -C "$repo" rev-parse main)" "main unchanged"
  assert_eq ready "$(hub ticket get T-001 status)" "status"
  assert_eq red "$(hub ticket get T-001 eval)" "eval"
  [ -d "$repo/.claude/worktrees/T-001" ] || fail "worktree removed"
}

test_merge_none_path_with_spaces() {
  setup_both
  local repo="$HUB_DIR/demo proj"
  hub new --project demo --title "N" --files "a b.txt" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_TOUCH="a b.txt" hub dispatch T-001 --wait || fail "dispatch"
  echo changed > "$repo/keep.txt"
  echo stray > "$repo/other.txt"
  hub merge T-001 >"$TMP_ROOT/merge.out" || fail "merge"
  assert_eq "a b.txt" "$(git -C "$repo" show --name-only --format= HEAD)" "commit files"
  git -C "$repo" log --format=%s -n 1 | grep -q '^hub(T-001): N$' || fail "commit msg"
  local st
  st=$(git -C "$repo" status --porcelain | sort | tr '\n' '|')
  assert_eq ' M keep.txt|?? other.txt|' "$st" "unrelated stays dirty"
  assert_eq done "$(hub ticket get T-001 status)" "status"
  events_last | grep -q ' done T-001$' || fail "events.log"
  assert_grep 'committed' "$(tfile T-001)"
}

test_merge_none_fallback_final_json() {
  setup_both
  local repo="$HUB_DIR/demo proj"
  hub new --project demo --title "F" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_TOUCH="out.txt" FAKE_CLAUDE_RESULT=$'Done.\n\nStatus: ready\nEval: n/a\nFiles: '"$repo/out.txt"$' (new)\nNote: none' \
    hub dispatch T-001 --wait || fail "dispatch"
  [ -z "$(hub ticket get T-001 files)" ] || fail "ticket files not empty"
  hub merge T-001 >"$TMP_ROOT/merge.out" || fail "merge"
  assert_eq "out.txt" "$(git -C "$repo" show --name-only --format= HEAD)" "commit files"
}

test_merge_requires_ready() {
  setup_both
  hub new --project demo --title "O" <<< 'b' >/dev/null || fail "new"
  local rc=0
  hub merge T-001 2>/dev/null || rc=$?
  assert_eq 1 "$rc" "exit"
  assert_eq open "$(hub ticket get T-001 status)" "status"
}

test_merge_main_not_checked_out() {
  setup_both
  hub new --project gitproj --title "M" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_TOUCH=new.txt hub dispatch T-001 --wait || fail "dispatch"
  local repo="$HUB_DIR/git proj" before rc=0 out
  git -C "$repo" checkout -q -b other || fail "checkout"
  before=$(git -C "$repo" rev-parse main)
  out=$(hub merge T-001 2>&1) || rc=$?
  assert_eq 1 "$rc" "exit"
  echo "$out" | grep -q 'main' || fail "message: $out"
  assert_eq "$before" "$(git -C "$repo" rev-parse main)" "main unchanged"
  assert_eq ready "$(hub ticket get T-001 status)" "status"
  [ -d "$repo/.claude/worktrees/T-001" ] || fail "worktree removed"
}

test_merge_in_progress_merge() {
  setup_both
  hub new --project gitproj --title "IP" <<< 'b' >/dev/null || fail "new"
  FAKE_CLAUDE_TOUCH=new.txt hub dispatch T-001 --wait || fail "dispatch"
  local repo="$HUB_DIR/git proj" rc=0 out
  ( cd "$repo" && git checkout -q -b side && echo s > f && git commit -q -am side \
    && git checkout -q main && echo m > f && git commit -q -am mainchange && { git merge side >"$TMP_ROOT/m.out" 2>&1; true; } ) || fail "setup merge"
  git -C "$repo" rev-parse -q --verify MERGE_HEAD >"$TMP_ROOT/mh" || fail "no MERGE_HEAD in setup"
  out=$(hub merge T-001 2>&1) || rc=$?
  assert_eq 1 "$rc" "exit"
  echo "$out" | grep -q 'merge in progress' || fail "message: $out"
  git -C "$repo" rev-parse -q --verify MERGE_HEAD >"$TMP_ROOT/mh2" || fail "MERGE_HEAD wiped"
  assert_eq ready "$(hub ticket get T-001 status)" "status"
}

test_merge_none_literal_pathspec() {
  setup_both
  local repo="$HUB_DIR/demo proj" rc=0 before
  mkdir -p "$repo/src"
  echo a > "$repo/src/a.ts"
  hub new --project demo --title "L" --files 'src/*.ts' <<< 'b' >/dev/null || fail "new"
  hub ticket set T-001 status ready
  before=$(git -C "$repo" rev-parse HEAD)
  hub merge T-001 >"$TMP_ROOT/o" 2>&1 || rc=$?
  assert_eq 1 "$rc" "exit"
  assert_eq "$before" "$(git -C "$repo" rev-parse HEAD)" "nothing committed"
  assert_eq "" "$(git -C "$repo" diff --cached --name-only)" "nothing staged"
}

test_merge_none_wrong_branch() {
  setup_both
  local repo="$HUB_DIR/demo proj" rc=0 before
  hub new --project demo --title "B" --files "keep.txt" <<< 'b' >/dev/null || fail "new"
  hub ticket set T-001 status ready
  echo changed > "$repo/keep.txt"
  git -C "$repo" checkout -q -b other || fail "checkout"
  before=$(git -C "$repo" rev-parse HEAD)
  hub merge T-001 >"$TMP_ROOT/o" 2>&1 || rc=$?
  assert_eq 1 "$rc" "exit"
  assert_eq "$before" "$(git -C "$repo" rev-parse HEAD)" "nothing committed"
  assert_eq ready "$(hub ticket get T-001 status)" "status"
}

test_eval_set_keeps_log() {
  setup_both
  hub new --project demo --title "K" <<< 'b' >/dev/null || fail "new"
  hub ticket eval-set T-001 "true" || fail "set1"
  hub ticket eval-set T-001 "echo two" || fail "set2"
  local f
  f=$(tfile T-001)
  assert_eq 1 "$(grep -c '^```check' "$f")" "one block"
  assert_grep '^echo two$' "$f"
  assert_grep '^## Log$' "$f"
  assert_grep 'created' "$f"
  hub ticket eval-set T-001 'a ``` b' 2>/dev/null && fail "fence accepted"
  return 0
}

test_eval_green_red
test_eval_timeout
test_merge_in_progress_merge
test_merge_none_literal_pathspec
test_merge_none_wrong_branch
test_eval_set_keeps_log
test_propose
test_propose_requires_ready
test_propose_telegram
test_merge_worktree
test_merge_conflict
test_merge_reeval_red
test_merge_none_path_with_spaces
test_merge_none_fallback_final_json
test_merge_requires_ready
test_merge_main_not_checked_out
echo "PASS $0"
