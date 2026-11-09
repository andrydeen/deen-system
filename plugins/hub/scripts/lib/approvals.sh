# approvals.sh — hub approval: read / advance an approval record's status. bash 3.2 safe.
#
# Vocabulary of the approval-gate skill: pending -> approved-executing -> approved-executed,
# pending | approved-executing -> rejected. Terminal states get a `resolved:` line.

# hub approval <id> [approved-executing|approved-executed|rejected]
cmd_approval() {
  local id="${1:-}" new="${2:-}" f out rc
  [ $# -le 2 ] && [ -n "$id" ] || hub_die "usage: hub approval <id> [approved-executing|approved-executed|rejected]"
  # Any record in the approvals directory (hub's T-NNN-N or the approval-gate skill's hex
  # ids); no '/' and no leading '.', so the path stays inside $APPROVALS_DIR.
  printf '%s\n' "$id" | grep -Eqx '[A-Za-z0-9][A-Za-z0-9_.-]*' || hub_die "approval: bad id: $id"
  f="$APPROVALS_DIR/$id.md"
  [ -f "$f" ] || hub_die "approval: unknown id: $id"
  case "$new" in
    ''|approved-executing|approved-executed|rejected) ;;
    *) hub_die "approval: unknown status: $new (approved-executing|approved-executed|rejected)" ;;
  esac
  hub_lock "$APPROVALS_DIR/.lock-$id"
  out=$(python3 -c '
import os, sys, tempfile, time
path, new = sys.argv[1], sys.argv[2]
NEXT = {"approved-executing": ("pending",),
        "approved-executed": ("approved-executing",),
        "rejected": ("pending", "approved-executing")}
lines = open(path, encoding="utf-8").read().split("\n")
if not lines or lines[0] != "---" or "---" not in lines[1:]:
    print("approval: %s has no frontmatter" % path); sys.exit(1)
end = lines.index("---", 1)
idx = [i for i in range(1, end) if lines[i].startswith("status:")]
if not idx:
    print("approval: %s has no status line" % path); sys.exit(1)
cur = lines[idx[0]].split(":", 1)[1].strip()
if not new:
    print(cur); sys.exit(0)
if cur not in NEXT[new]:
    print("approval: cannot go from %s to %s" % (cur, new)); sys.exit(1)
lines[idx[0]] = "status: %s" % new
if new in ("approved-executed", "rejected"):
    lines[end:end] = ["resolved: %s" % time.strftime("%Y-%m-%d %H:%M")]
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    os.replace(tmp, path)
except BaseException:
    if os.path.exists(tmp):
        os.unlink(tmp)
    raise
print(new)
' "$f" "$new")
  rc=$?
  hub_unlock "$APPROVALS_DIR/.lock-$id"
  if [ "$rc" -ne 0 ]; then echo "hub: ${out:-approval: update failed}" >&2; return 1; fi
  if [ -z "$new" ]; then echo "$out"; else echo "$id: $out"; fi
}
