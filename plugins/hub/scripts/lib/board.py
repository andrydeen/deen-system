#!/usr/bin/env python3
"""Console board and ticket detail for hub. Stdlib only."""
import json
import os
import sys
import tempfile
import time
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tickets  # noqa: E402
import events  # noqa: E402

COLUMNS = (("ID", 6), ("PROJECT", 12), ("TITLE", 28), ("STATUS", 10), ("MODE", 5),
           ("DEPS", 10), ("NOW", 40), ("ELAPSED", 7), ("LAST", 40), ("FLAGS", 8))
FLAG_MAP = {"stall": "⚠stall", "loop": "⚠loop", "budget": "💰", "dead": "⚠dead"}
STATUS_ORDER = ("running", "blocked", "ready", "open")


def runs_dir(tid):
    return os.path.join(tickets.hub_dir(), ".runs", tid)


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def parse_time(s):
    s = s.strip()
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    return None


def fmt_elapsed(run):
    start = parse_time(read(os.path.join(run, "started")))
    if start is None:
        return ""
    end = parse_time(read(os.path.join(run, "ended"))) or datetime.now()
    mins = max(0, int((end - start).total_seconds() // 60))
    if mins < 60:
        return "%dm" % mins
    return "%dh%02dm" % (mins // 60, mins % 60)


def final_json(run):
    try:
        d = json.loads(read(os.path.join(run, "final.json")))
    except ValueError:
        return {}
    return d if isinstance(d, dict) else {}


def progress_file(run):
    # the "project" entry is a file holding the worker cwd (or a directory)
    pf = os.path.join(run, "project")
    if os.path.isdir(pf):
        cand = os.path.join(pf, "progress.log")
        if os.path.exists(cand):
            return cand
    elif os.path.isfile(pf):
        cwd = read(pf).strip()
        cand = os.path.join(cwd, "progress.log")
        if cwd and os.path.exists(cand):
            return cand
    return os.path.join(run, "progress.log")


def flags_of(fm):
    out = []
    for f in str(fm.get("flag", "")).split(","):
        f = f.strip()
        if f in FLAG_MAP:
            out.append(FLAG_MAP[f])
    hold = str(fm.get("hold", "")).strip()
    if hold and hold != "none":
        out.append("⏸")
    return " ".join(out)


def rows(include_all=False):
    out = []
    for tid in tickets.all_ids():
        fm = tickets.load(tid)
        status = fm.get("status", "")
        if status in ("done", "dropped") and not include_all:
            continue
        run = runs_dir(tid)
        fin = final_json(run)
        ev = os.path.join(run, "events.jsonl")
        now = ""
        if os.path.exists(ev) or os.path.exists(progress_file(run)):
            now = events.now_doing(ev, progress_file(run))
        last = str(fin.get("note") or fin.get("question") or "")[:40]
        deps = fm.get("deps") or []
        if not isinstance(deps, list):
            deps = [deps]
        try:
            cost = float(fin.get("cost_usd") or 0.0)
        except (TypeError, ValueError):
            cost = 0.0
        out.append({
            "id": tid, "project": fm.get("project", ""), "title": fm.get("title", ""),
            "status": status, "mode": fm.get("mode", ""), "deps": deps,
            "now": now, "elapsed": fmt_elapsed(run), "last": last,
            "flags": flags_of(fm), "path": fm.get("path", ""),
            "worktree": read(os.path.join(run, "worktree")).strip(),
            "session_id": read(os.path.join(run, "session-id")).strip(),
            "cost_usd": cost,
            "run_status": read(os.path.join(run, "status")).strip(),
            "hold": fm.get("hold", ""),
        })

    def key(r):
        st = STATUS_ORDER.index(r["status"]) if r["status"] in STATUS_ORDER else len(STATUS_ORDER)
        return (0 if r["flags"] else 1, st)
    out.sort(key=key)  # stable: ids stay ordered within a group
    return out


def cell(v, width):
    v = " ".join(str(v).split())
    return v[:width].ljust(width)


def render(rs):
    sep = " · "
    lines = [sep.join(cell(n, w) for n, w in COLUMNS).rstrip()]
    if not rs:
        lines.append("(no tickets)")
    for r in rs:
        vals = [r["id"], r["project"], r["title"], r["status"], r["mode"],
                ",".join(r["deps"]), r["now"], r["elapsed"], r["last"], r["flags"]]
        lines.append(sep.join(cell(v, w) for v, (_, w) in zip(vals, COLUMNS)).rstrip())
    return "\n".join(lines)


def write_board_json(rs):
    d = tickets.hub_dir()
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".board.", dir=d)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump({"generated": datetime.now().isoformat(timespec="seconds"), "rows": rs},
                      f, ensure_ascii=False, indent=1)
        os.replace(tmp, os.path.join(d, "board.json"))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def tool_calls(run, limit=30):
    evs, _ = events.read_events(os.path.join(run, "events.jsonl"))
    calls = []
    for obj, _ts in evs:
        stamp = obj.get("timestamp") if isinstance(obj.get("timestamp"), str) else "--:--"
        for tu in events.tool_uses(obj):
            calls.append("%s %s" % (stamp, events.summarize(tu)))
    return calls[-limit:]


def show(ticket_id):
    fm = tickets.load(ticket_id)
    run = runs_dir(ticket_id)
    out = ["## Ticket"]
    for k, v in fm.items():
        if k in tickets.SKIP_KEYS:
            continue
        out.append("%s: %s" % (k, ", ".join(v) if isinstance(v, list) else v))
    out += ["", "## Brief", str(fm.get("brief", "")).rstrip() or "(none)"]
    steer = read(os.path.join(run, "briefs.log")).strip()
    out += ["", "## Steering", steer or "(none)"]
    prog = read(progress_file(run)).strip()
    out += ["", "## Progress", prog or "(none)"]
    out += ["", "## Tool calls"] + (tool_calls(run) or ["(none)"])
    rep = read(os.path.join(run, "report.md")).strip()
    out += ["", "## Report", rep or "(none)"]
    wt = read(os.path.join(run, "worktree")).strip()
    pend = os.path.join(run, "pending")
    npend = len(os.listdir(pend)) if os.path.isdir(pend) else 0
    out += ["", "## Run",
            "status: %s" % (read(os.path.join(run, "status")).strip() or "(none)"),
            "round: %s" % (read(os.path.join(run, "round")).strip() or "(none)")]
    if wt:
        out.append("worktree: %s" % wt)
        if os.path.isdir(wt):
            out.append("branch: hub/%s" % ticket_id)
    out.append("pending: %d" % npend)
    out.append("cost_usd: %s" % final_json(run).get("cost_usd", 0.0))
    return "\n".join(out)


def main(argv):
    if not argv or argv[0] not in ("board", "show"):
        tickets.die("usage: board.py board [--json] [--watch] [--all] | show <ticket>")
    cmd, args = argv[0], argv[1:]
    if cmd == "show":
        if len(args) != 1:
            tickets.die("usage: hub show <ticket>")
        try:
            print(show(args[0]))
        except OSError:
            tickets.die("no such ticket: %s" % args[0])
        return 0
    unknown = [a for a in args if a not in ("--json", "--watch", "--all")]
    if unknown:
        tickets.die("usage: hub board [--json] [--watch] [--all]")
    inc = "--all" in args
    if "--watch" in args:
        try:
            while True:
                sys.stdout.write("\x1b[2J\x1b[H" + render(rows(inc)) + "\n")
                sys.stdout.flush()
                time.sleep(5)
        except KeyboardInterrupt:
            return 0
    rs = rows(inc)
    write_board_json(rs)
    if "--json" in args:
        print(json.dumps(rs, ensure_ascii=False, indent=1))
    else:
        print(render(rs))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
