. "$(dirname "$0")/helpers.sh"; setup_hub
assert_file "$HUB_DIR/INDEX.md"; assert_file "$HUB_DIR/projects.yaml"; assert_file "$HUB_DIR/config"
assert_file "$HUB_DIR/bin/hub"; test -d "$HUB_DIR/tickets" || fail tickets; test -d "$HUB_DIR/.runs/.slots" || fail slots
assert_grep "WORKER_AGENT_MODE=agent" "$HUB_DIR/config"
assert_grep "EVENT_DELIVERY=monitor" "$HUB_DIR/config"
assert_file "$HUB_DIR/.runs/events.log"
out=$(hub --help); echo "$out" | grep -q "dispatch" || fail "help lists subcommands"
hub nosuch 2>/dev/null && fail "unknown subcommand must exit 1"
# idempotent: existing config and projects.yaml are never overwritten
echo "WORKER_AGENT_MODE=custom" > "$HUB_DIR/config"; echo "mine: 1" > "$HUB_DIR/projects.yaml"
hub init >/dev/null || fail "second init"
assert_grep "WORKER_AGENT_MODE=custom" "$HUB_DIR/config"; assert_grep "mine: 1" "$HUB_DIR/projects.yaml"
# bin/hub wrapper reaches the dispatcher
"$HUB_DIR/bin/hub" --help | grep -q dispatch || fail "bin/hub wrapper"
# fake claude is wired
claude -p "x" --session-id abc --output-format stream-json > "$HUB_DIR/f.jsonl"; assert_grep '"type": *"result"' "$HUB_DIR/f.jsonl"
assert_file "$FAKE_CLAUDE_STATE/abc"
claude -p "x" --resume nope >/dev/null 2>&1 && fail "resume of unknown id must fail"
assert_grep '"cwd"' "$FAKE_CLAUDE_LOG"
echo "PASS $0"
