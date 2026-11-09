. "$(dirname "$0")/helpers.sh"; setup_hub
printf 'demo:\n  path: "%s/demo proj"\n  isolation: none\n' "$HUB_DIR" > "$HUB_DIR/projects.yaml"
id=$(hub new --project demo --title "Hello" <<< 'say "hi" $USER') || fail "new"
assert_eq "T-001" "$id" "first id"
f=$(ls "$HUB_DIR"/tickets/T-001-*.md); assert_file "$f"
assert_eq "$HUB_DIR/tickets/T-001-hello.md" "$f" "slug filename"
assert_grep "^status: open$" "$f"; assert_grep "^isolation: none$" "$f"
assert_grep "^deps: \[\]$" "$f"; assert_grep "^hold: none$" "$f"
grep -qF 'say "hi" $USER' "$f" || fail "brief verbatim"
assert_eq 'say "hi" $USER' "$(hub ticket brief T-001)" "brief cmd"
assert_eq "$HUB_DIR/demo proj" "$(hub ticket get T-001 path)" "path with space"
id=$(hub new --project demo --title "Second one" --deps T-001 --files a,b <<< 'b2') || fail "new 2"
assert_eq "T-002" "$id" "second id"
assert_grep "^deps: \[T-001\]$" "$HUB_DIR/tickets/T-002-second-one.md"
assert_grep "^files: \[a, b\]$" "$HUB_DIR/tickets/T-002-second-one.md"
hub set T-001 status running || fail "set"
assert_grep "^- T-001 · demo · Hello · running · deps: none · hold: none$" "$HUB_DIR/INDEX.md"
assert_grep "^- T-002 · demo · Second one · open · deps: T-001 · hold: none$" "$HUB_DIR/INDEX.md"
hub set T-001 flag "needs look"
assert_grep "^- ⚠ T-001 · demo" "$HUB_DIR/INDEX.md"
hub set T-002 status done
grep -q "T-002" "$HUB_DIR/INDEX.md" && fail "done ticket must leave INDEX"
hub note T-001 "dispatched" || fail "note"
assert_grep "^- [0-9T:-]+ dispatched$" "$f"
tail -c1 "$f" | od -c | grep -q '\\n' || fail "ends with newline"
hub new --project nosuch --title X <<< b 2>/dev/null && fail "unknown project must exit 1"
hub set T-099 status x 2>/dev/null && fail "unknown ticket must exit 1"
hub note T-099 x 2>/dev/null && fail "note unknown ticket must exit 1"
test_new_concurrent_ids() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do hub new --project demo --title "c$i" <<< "b$i" >/dev/null & done
  wait
  [ -z "$(hub ticket list | sort | uniq -d)" ] || fail "duplicate ids"
  assert_eq 12 "$(hub ticket list | wc -l | tr -d ' ')" "12 ids"
}
test_new_concurrent_ids
assert_eq 12 "$(hub ticket list | wc -l | tr -d ' ')" "list count"
echo "PASS $0"
