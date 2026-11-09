#!/usr/bin/env python3
"""Watchdog pass: flag stalled, looping, dead and over-budget workers. Stdlib only."""
import argparse
import json
import os
import sys
import time
from datetime import datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tickets  # noqa: E402
import events  # noqa: E402

ORDER = ("stall", "loop", "dead", "budget")
LIVE = ("starting", "queued", "running", "finishing")
OPTS = {"stall_min": 15.0, "loop_edits": 8, "loop_window_min": 30.0, "repeat_calls": 10}


def run_dir(tid):
    return os.path.join(tickets.hub_dir(), ".runs", tid)


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read().strip()
    except OSError:
        return ""


def is_live(status):
    return status in LIVE or status.split(" ")[0] == "retrying"


def pid_alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except OSError:
        return False
    return True


def read_pid(run):
    txt = read(os.path.join(run, "pid"))
    return int(txt) if txt.isdigit() else None


def age_min(path):
    try:
        return (time.time() - os.path.getmtime(path)) / 60.0
    except OSError:
        return None


def max_budget():
    try:
        return float(os.environ.get("HUB_MAX_BUDGET_USD", "8"))
    except ValueError:
        return 8.0


def money(x):
    return ("%g" % x) if x == int(x) else ("%.2f" % x)


def details(tid, opts=None):
    """Return {flag: detail} for a ticket whose run status is live."""
    o = dict(OPTS, **(opts or {}))
    run = run_dir(tid)
    status = read(os.path.join(run, "status"))
    out = {}
    if not is_live(status):
        return out
    ev = os.path.join(run, "events.jsonl")
    st = events.stats(ev, o["loop_window_min"])
    if status == "running" and os.path.exists(os.path.join(run, "claude-pid")):
        cwd = read(os.path.join(run, "project"))
        prog = os.path.join(cwd, "progress.log") if cwd else ""
        if not prog or not os.path.exists(prog):
            prog = os.path.join(run, "progress.log")
        ages = [age_min(ev), age_min(prog)]
        ages = [a if a is not None else float("inf") for a in ages]
        newest = min(ages)
        if newest == float("inf"):
            out["stall"] = "no output files"
        elif newest > o["stall_min"]:
            out["stall"] = "no output for %d min" % int(newest)
    if status == "running":
        hot = sorted(((n, f) for f, n in st["edits_per_file"].items() if n >= o["loop_edits"]),
                     reverse=True)
        if hot:
            out["loop"] = "%d edits of %s in %g min" % (hot[0][0], hot[0][1], o["loop_window_min"])
        elif st["max_repeat_call"] > o["repeat_calls"]:
            out["loop"] = "same call ×%d" % st["max_repeat_call"]
    pid = read_pid(run)
    if pid is None and status == "starting":
        pass  # dispatch has not written the pid yet: grace
    elif pid is None or not pid_alive(pid):
        out["dead"] = "pid %s not alive" % (pid if pid is not None else "missing")
    cost = st["cost_usd"]
    if cost <= 0:
        try:
            cost = float(json.loads(read(os.path.join(run, "final.json")) or "{}").get("cost_usd") or 0)
        except (ValueError, AttributeError):
            cost = 0.0
    cap = max_budget()
    if cost >= cap:
        out["budget"] = "$%.2f ≥ $%s" % (cost, money(cap))
    return out


def check(ticket_id):
    d = details(ticket_id)
    return [f for f in ORDER if f in d]


def main(argv):
    ap = argparse.ArgumentParser(prog="watch.py")
    sp = ap.add_subparsers(dest="cmd")
    w = sp.add_parser("watch")
    w.add_argument("--stall-min", type=float, default=OPTS["stall_min"])
    w.add_argument("--loop-edits", type=int, default=OPTS["loop_edits"])
    w.add_argument("--loop-window-min", type=float, default=OPTS["loop_window_min"])
    w.add_argument("--repeat-calls", type=int, default=OPTS["repeat_calls"])
    try:
        args = ap.parse_args(argv)
    except SystemExit as e:
        sys.exit(1 if e.code else 0)
    if args.cmd != "watch":
        tickets.die("usage: watch.py watch [options]")
    opts = {"stall_min": args.stall_min, "loop_edits": args.loop_edits,
            "loop_window_min": args.loop_window_min, "repeat_calls": args.repeat_calls}
    stamp = datetime.now().strftime("%Y-%m-%dT%H:%M")
    log = os.path.join(tickets.hub_dir(), ".runs", "events.log")
    changed = False
    for tid in tickets.all_ids():
        if not is_live(read(os.path.join(run_dir(tid), "status"))):
            continue
        det = details(tid, opts)
        flags = [f for f in ORDER if f in det]
        with tickets.flock(tid + ".lock"):
            fm = tickets.load(tid)
            before = [x for x in str(fm.get("flag") or "").split(",") if x]
            new = ",".join(flags)
            if new != str(fm.get("flag") or ""):
                fm["flag"] = new
                tickets.save(tid, fm)
                changed = True
        for f in flags:
            line = "⚠ %s %s %s" % (f, tid, det[f])
            print(line)
            if f not in before:
                with open(log, "a", encoding="utf-8") as fh:
                    fh.write("%s %s\n" % (stamp, line))
    if changed:
        tickets.regen_index()


if __name__ == "__main__":
    main(sys.argv[1:])
