. "$(dirname "$0")/helpers.sh"
EV="python3 $PLUGIN_ROOT/scripts/lib/events.py"
FX="$TESTS_DIR/fixtures"
TMP="$(mktemp -d)"; trap 'rm -r -f -- "$TMP"' EXIT
pj() { python3 -c "import json,sys; d=json.load(sys.stdin); assert $1, d"; }

assert_eq "Edit /p/a.xml" "$($EV now-doing "$FX/events-ready.jsonl" "$TMP/none.log")" "now-doing tool"
assert_eq "Bash: ls" "$($EV now-doing "$FX/events-no-block.jsonl" "$TMP/none.log")" "now-doing bash"
assert_eq "" "$($EV now-doing "$TMP/no1" "$TMP/no2")" "both missing"
cp "$FX/events-ready.jsonl" "$TMP/ev.jsonl"
printf '10:01  start\n10:02  checking IFs\n' > "$TMP/progress.log"
touch -t 202001010000 "$TMP/progress.log"
assert_eq "Edit /p/a.xml" "$($EV now-doing "$TMP/ev.jsonl" "$TMP/progress.log")" "older progress loses"
sleep 1; touch "$TMP/progress.log"
assert_eq "10:02  checking IFs" "$($EV now-doing "$TMP/ev.jsonl" "$TMP/progress.log")" "newer progress wins"
assert_eq "10:02  checking IFs" "$($EV now-doing "$TMP/none.jsonl" "$TMP/progress.log")" "only progress"

$EV final "$FX/events-ready.jsonl" | pj "d['status']=='ready' and d['eval']=='green' and d['files']==['/p/a.xml (new)'] and d['cost_usd']==0.42 and d['note']=='' and d['question']=='' and d['denied']==0 and d['text'].endswith('Note: none')" || fail "final ready"
$EV final "$FX/events-no-block.jsonl" | pj "d['status']=='unknown-report' and d['note']=='missing report block' and d['files']==[]" || fail "final no-block"
$EV final "$FX/events-interrupted.jsonl" | pj "d['status']=='unknown-report' and d['note']=='error_during_execution: interrupted' and d['denied']==2 and d['eval']=='n/a' and d['cost_usd']==0.1" || fail "final interrupted"
$EV final "$FX/events-interrupted.jsonl" | pj "d['denied_tools']==['Write','Bash']" || fail "denied_tools"
assert_eq "interrupted" "$($EV errors "$FX/events-interrupted.jsonl")" "errors interrupted"
assert_eq "" "$($EV errors "$FX/events-ready.jsonl")" "errors ready"
$EV final "$TMP/no1" | pj "d['status']=='unknown-report' and d['note']=='no result line'" || fail "final no result"
# I2: the real binary's API-error shape (is_error result, no errors[])
$EV final "$FX/events-api-error.jsonl" | pj "d['status']=='unknown-report' and d['eval']=='n/a' and d['files']==[] and d['note']=='API Error: 529 overloaded'" || fail "final api error"
$EV errors "$FX/events-api-error.jsonl" > "$TMP/apierr"
grep -qx '529' "$TMP/apierr" || fail "errors lacks 529: $(cat "$TMP/apierr")"
grep -q '^API Error: 529 overloaded' "$TMP/apierr" || fail "errors lacks text: $(cat "$TMP/apierr")"
grep -qx 'overloaded_error' "$TMP/apierr" || fail "errors lacks assistant error: $(cat "$TMP/apierr")"
# R3: is_error with no result text falls through to subtype + errors[]
printf '%s\n' '{"type":"result","subtype":"error_during_execution","is_error":true,"result":null,"errors":["interrupted"]}' > "$TMP/iserr.jsonl"
$EV final "$TMP/iserr.jsonl" | pj "d['status']=='unknown-report' and d['note']=='error_during_execution: interrupted'" || fail "is_error without text"
# M7: a bolded report block inside a code fence still parses
$EV final "$FX/events-fenced.jsonl" | pj "d['status']=='ready' and d['eval']=='green' and d['files']==['/p/a.xml (new)'] and d['note']==''" || fail "final fenced/bold"
printf '%s\n' '{"type":"result","subtype":"success","result":"**Status:** maybe\nEval: n/a\nFiles: none\nNote: none"}' > "$TMP/badst.jsonl"
$EV final "$TMP/badst.jsonl" | pj "d['status']=='unknown-report'" || fail "bad status still unknown-report"

$EV stats "$FX/events-loop.jsonl" --window-min 30 | pj "d['edits_per_file']=={'/p/a.xml':9} and d['max_repeat_call']==11 and d['last_event_ts'].startswith('2026-11-09T16:28') and d['skipped']==0" || fail "stats loop"
$EV stats "$FX/events-loop.jsonl" --window-min 10 | pj "d['edits_per_file']=={'/p/a.xml':0} or d['edits_per_file']=={}" || fail "stats window"
$EV stats "$FX/events-ready.jsonl" --window-min 30 | pj "d['cost_usd']==0.42 and d['edits_per_file']=={'/p/a.xml':1}" || fail "stats ready"
printf 'not json\n{"type":"result","subtype":"success","result":"x"}\n' > "$TMP/bad.jsonl"
$EV stats "$TMP/bad.jsonl" --window-min 30 | pj "d['skipped']==1" || fail "skipped"
# I6: total_cost_usd sums every result line (all rounds); cost_usd stays the last one
printf '%s\n' '{"type":"result","subtype":"success","result":"x","total_cost_usd":0.42}' \
  '{"type":"result","subtype":"success","result":"y","total_cost_usd":0.5}' > "$TMP/two.jsonl"
$EV stats "$TMP/two.jsonl" --window-min 30 | pj "d['total_cost_usd']==0.92 and d['cost_usd']==0.5" || fail "stats total cost"
$EV final "$TMP/two.jsonl" | pj "d['cost_usd']==0.5" || fail "final keeps last round cost"
echo "PASS $0"
