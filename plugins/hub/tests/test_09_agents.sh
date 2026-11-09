. "$(dirname "$0")/helpers.sh"; setup_hub
A="$PLUGIN_ROOT/agents"; T="$PLUGIN_ROOT/templates"

fm_check() { # file key=value ...
  python3 - "$@" <<'PY' || fail "frontmatter of $1"
import sys
f = sys.argv[1]
lines = open(f).read().split("\n")
assert lines[0] == "---", "no frontmatter"
end = lines.index("---", 1)
fm = {}
for l in lines[1:end]:
    k, _, v = l.partition(":")
    v = v.strip()
    if k.strip() == "description":
        assert v.startswith('"') and v.endswith('"'), "description must be double-quoted"
        v = v[1:-1]
    fm[k.strip()] = v
for kv in sys.argv[2:]:
    k, _, v = kv.partition("=")
    assert fm.get(k) == v, "%s: expected %r got %r" % (k, v, fm.get(k))
PY
}
fm_check "$A/hub-router.md" name=hub-router \
  "description=Router for the hub: talks to the human, dispatches and verifies background workers, never does the work itself." \
  model=sonnet effort=medium "disallowedTools=Edit, Write, NotebookEdit"
fm_check "$A/hub-worker.md" name=hub-worker \
  "description=Hub worker: one ticket, one project directory, reports in the four-line block." \
  model=opus effort=medium "tools=Read, Edit, Write, Bash, Grep, Glob, WebFetch, WebSearch, Agent"

for p in "hub propose" "hub send" "never do the work" "hub board" "hub eval" "approved-executing" "Exact steps" "CronCreate" "Monitor"; do
  grep -qF -- "$p" "$A/hub-router.md" || fail "router missing: $p"
done
grep -qF './bin/hub approval' "$A/hub-router.md" || fail "router RESOLVE uses hub approval"
grep -q 'sed' "$A/hub-router.md" && fail "router must not tell the Router to sed records"
grep -qF 'approval' "$T/hub-CLAUDE.md" || fail "hub-CLAUDE approval line"
n=$(wc -l < "$A/hub-router.md" | tr -d ' '); [ "$n" -le 125 ] || fail "router too long: $n"
n=$(wc -l < "$A/hub-worker.md" | tr -d ' '); [ "$n" -le 20 ] || fail "worker too long: $n"
for f in "$A/hub-router.md" "$A/hub-worker.md"; do
  grep -Eq '^description: ".*"$' "$f" || fail "description not quoted in $f"
done
# operator identifiers are the release guard's job (below); here: no private home paths
hits=$(grep -rnE '/Users/[a-z]+/' "$PLUGIN_ROOT" 2>/dev/null)
[ -z "$hits" ] || fail "private home path under plugins/hub: $hits"

for p in '{{TICKET}}' 'Status:' 'Eval:' 'Files:' 'Note:'; do grep -qF -- "$p" "$T/worker-rules.md" || fail "worker-rules missing $p"; done
grep -qF '{{TICKET}}' "$T/brief.md" || fail "brief {{TICKET}}"
grep -qF 'verbatim' "$T/brief.md" || fail "brief verbatim"
grep -qF 'bin/hub' "$T/hub-CLAUDE.md" || fail "hub-CLAUDE bin/hub"

assert_file "$HUB_DIR/CLAUDE.md"; assert_grep "hub-router" "$HUB_DIR/CLAUDE.md"
echo "mine" > "$HUB_DIR/CLAUDE.md"; hub init >/dev/null || fail "re-init"
assert_grep "^mine$" "$HUB_DIR/CLAUDE.md"

hub --help | grep -q watchdog || fail "help mentions watchdog"
hub --help | grep -q 'approval' || fail "help mentions approval"
grep -qF 'hub init' "$PLUGIN_ROOT/README.md" || fail "README hub init"
grep -qF -- '--agent hub-router' "$PLUGIN_ROOT/README.md" || fail "README start command"
n=$(wc -l < "$PLUGIN_ROOT/README.md" | tr -d ' '); [ "$n" -le 200 ] || fail "README too long: $n"

( cd "$PLUGIN_ROOT/../.." && bash scripts/release-check.sh >/dev/null ) || fail "release-check"
( cd "$PLUGIN_ROOT/../.." && python3 -m json.tool plugins/hub/.claude-plugin/plugin.json >/dev/null ) || fail "plugin.json"
echo "PASS $0"
