#!/usr/bin/env python3
"""Parse a worker's stream-json events.jsonl. Stdlib only, no side effects."""
import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone

STATUSES = ("ready", "blocked", "failed", "dropped")
DENIED_PREFIX = "The user doesn't want to proceed"
EDIT_TOOLS = ("Edit", "MultiEdit", "Write")


def die(msg):
    sys.stderr.write("hub: %s\n" % msg)
    sys.exit(1)


def read_events(path):
    """Return (list of (obj, ts_or_None), skipped_count). Missing file -> empty."""
    out, skipped = [], 0
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    obj = json.loads(line)
                except ValueError:
                    skipped += 1
                    continue
                if not isinstance(obj, dict):
                    skipped += 1
                    continue
                out.append((obj, parse_ts(obj.get("timestamp"))))
    except OSError:
        pass
    return out, skipped


def parse_ts(s):
    if not isinstance(s, str):
        return None
    try:
        d = datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    return d if d.tzinfo else d.replace(tzinfo=timezone.utc)


def blocks(obj):
    msg = obj.get("message")
    content = msg.get("content") if isinstance(msg, dict) else None
    return [b for b in content if isinstance(b, dict)] if isinstance(content, list) else []


def tool_uses(obj):
    if obj.get("type") != "assistant":
        return []
    return [b for b in blocks(obj) if b.get("type") == "tool_use"]


def summarize(tu):
    name = tu.get("name") or "tool"
    inp = tu.get("input") if isinstance(tu.get("input"), dict) else {}
    if name == "MultiEdit":
        name = "Edit"
    if name in ("Edit", "Write", "Read") and inp.get("file_path"):
        return "%s %s" % (name, inp["file_path"])
    if name == "Bash":
        return "Bash: %s" % str(inp.get("command", ""))[:60]
    if name in ("Glob", "Grep") and inp.get("pattern"):
        return "%s %s" % (name, inp["pattern"])
    return name


def mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return None


def last_line(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = [l.rstrip("\n") for l in f if l.strip()]
    except OSError:
        return ""
    return lines[-1] if lines else ""


def now_doing(ev, prog):
    events, _ = read_events(ev)
    last_tool = ""
    for obj, _ts in events:
        for tu in tool_uses(obj):
            last_tool = summarize(tu)
    m_ev, m_pr = mtime(ev), mtime(prog)
    prog_line = last_line(prog) if m_pr is not None else ""
    if m_ev is None and m_pr is None:
        return ""
    if m_ev is None:
        return prog_line
    if m_pr is None:
        return last_tool
    if m_pr > m_ev and prog_line:
        return prog_line
    return last_tool or prog_line


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(b.get("text", "") for b in content
                       if isinstance(b, dict) and b.get("type") == "text")
    return ""


def find_result(events):
    res = None
    for obj, _ts in events:
        if obj.get("type") == "result":
            res = obj
    return res


MARK = r"(?:\*\*|__|`)"
FENCE_RE = re.compile(r"^```[\w-]*$")


def unmark(line):
    """Strip markdown emphasis/code marks around a report line and its key:
    '**Status:** ready', '`Eval: green`', '__Files__: none' -> 'Key: value'."""
    l = re.sub(r"^%s+" % MARK, "", line.strip())
    l = re.sub(r"%s+$" % MARK, "", l)
    l = re.sub(r"^([A-Za-z]+)%s*:%s*" % (MARK, MARK), r"\1:", l)
    return l.strip()


def parse_block(text):
    """Return (dict, None) or (None, note)."""
    lines = [unmark(l) for l in text.splitlines() if l.strip() and not FENCE_RE.match(l.strip())]
    lines = [l for l in lines if l]
    tail = lines[-4:]
    pats = ("Status", "Eval", "Files", "Note|Question")
    if len(tail) < 4 or not all(re.match(r"^(%s):" % p, l) for p, l in zip(pats, tail)):
        return None, "missing report block"
    val = lambda l: l.split(":", 1)[1].strip()
    status = val(tail[0])
    if status not in STATUSES:
        return None, "bad status: %s" % status
    files_raw = val(tail[2])
    files = [] if files_raw == "none" else [x.strip() for x in files_raw.split(" ; ") if x.strip()]
    body = val(tail[3])
    if body == "none":
        body = ""
    is_q = tail[3].startswith("Question:")
    return {"status": status, "eval": val(tail[1]), "files": files,
            "note": "" if is_q else body, "question": body if is_q else ""}, None


def final(ev):
    events, _ = read_events(ev)
    denied = 0
    denied_tools = []
    names = {}
    for obj, _ts in events:
        for tu in tool_uses(obj):
            if tu.get("id"):
                names[tu["id"]] = tu.get("name") or "tool"
        if obj.get("type") != "user":
            continue
        for b in blocks(obj):
            if (b.get("type") == "tool_result" and b.get("is_error") is True
                    and text_of(b.get("content")).startswith(DENIED_PREFIX)):
                denied += 1
                denied_tools.append(names.get(b.get("tool_use_id"), "tool"))
    out = {"status": "unknown-report", "eval": "n/a", "files": [], "note": "",
           "question": "", "cost_usd": 0.0, "text": "", "denied": denied,
           "denied_tools": denied_tools}
    res = find_result(events)
    if res is None:
        out["note"] = "no result line"
        return out
    out["cost_usd"] = float(res.get("total_cost_usd") or 0.0)
    text = res.get("result")
    out["text"] = text if isinstance(text, str) else ""
    if res.get("is_error") is True:
        # API-level failure (e.g. 529 overloaded): subtype says "success", the text is the error.
        first = out["text"].strip().splitlines()[0].strip() if out["text"].strip() else ""
        out["note"] = first or "api error %s" % res.get("api_error_status", "")
        return out
    sub = res.get("subtype")
    if text is None or not isinstance(text, str) or sub != "success":
        note = str(sub or "no result")
        errs = res.get("errors")
        if isinstance(errs, list) and errs:
            note += ": %s" % errs[0]
        out["note"] = note
        return out
    parsed, note = parse_block(text)
    if parsed is None:
        out["note"] = note
        return out
    out.update(parsed)
    return out


def api_error_message(obj):
    """True for an assistant line that carries an API error (flag on the line or its message)."""
    msg = obj.get("message") if isinstance(obj.get("message"), dict) else {}
    return obj.get("type") == "assistant" and (obj.get("is_api_error_message") is True
                                               or msg.get("is_api_error_message") is True)


def errors(ev):
    """Error strings only: errors[] and a top-level error field of result/system lines; the
    result text and api_error_status of an is_error result line; the error and text of
    assistant lines flagged is_api_error_message."""
    events, _ = read_events(ev)
    out = []
    for obj, _ts in events:
        if api_error_message(obj):
            msg = obj.get("message") if isinstance(obj.get("message"), dict) else {}
            for e in (obj.get("error"), msg.get("error")):
                if isinstance(e, str) and e:
                    out.append(e)
            t = text_of(msg.get("content"))
            if t:
                out.append(t)
            continue
        if obj.get("type") not in ("result", "system"):
            continue
        if obj.get("type") == "result" and obj.get("is_error") is True:
            if isinstance(obj.get("result"), str) and obj["result"]:
                out.append(obj["result"])
            if obj.get("api_error_status") is not None:
                out.append(str(obj["api_error_status"]))
        errs = obj.get("errors")
        if isinstance(errs, list):
            out.extend(e for e in errs if isinstance(e, str))
        if isinstance(obj.get("error"), str):
            out.append(obj["error"])
    return [" ".join(e.split()) for e in out]


def stats(ev, window_min):
    events, skipped = read_events(ev)
    fallback = mtime(ev)
    fb = datetime.fromtimestamp(fallback, timezone.utc) if fallback is not None else None
    stamped = [(obj, ts or fb) for obj, ts in events]
    known = [ts for _o, ts in stamped if ts is not None]
    last = max(known) if known else None
    edits, calls = {}, {}
    for obj, ts in stamped:
        if last is not None and ts is not None and ts < last - timedelta(minutes=window_min):
            continue
        for tu in tool_uses(obj):
            inp = tu.get("input") if isinstance(tu.get("input"), dict) else {}
            if tu.get("name") in EDIT_TOOLS and inp.get("file_path"):
                edits[inp["file_path"]] = edits.get(inp["file_path"], 0) + 1
            key = (tu.get("name"), json.dumps(inp, sort_keys=True))
            calls[key] = calls.get(key, 0) + 1
    res = find_result(events)
    return {"edits_per_file": edits,
            "max_repeat_call": max(calls.values()) if calls else 0,
            "last_event_ts": last.isoformat().replace("+00:00", "Z") if last else "",
            "cost_usd": float(res.get("total_cost_usd") or 0.0) if res else 0.0,
            "total_cost_usd": total_cost(events),
            "skipped": skipped}


def total_cost(events):
    """Sum of total_cost_usd over every result line (all rounds of the ticket)."""
    tot = 0.0
    for obj, _ts in events:
        if obj.get("type") == "result":
            try:
                tot += float(obj.get("total_cost_usd") or 0.0)
            except (TypeError, ValueError):
                pass
    return round(tot, 6)


def main(argv):
    ap = argparse.ArgumentParser(prog="events.py")
    sp = ap.add_subparsers(dest="cmd")
    a = sp.add_parser("now-doing")
    a.add_argument("events")
    a.add_argument("progress")
    b = sp.add_parser("final")
    b.add_argument("events")
    e = sp.add_parser("errors")
    e.add_argument("events")
    c = sp.add_parser("stats")
    c.add_argument("events")
    c.add_argument("--window-min", type=float, default=30)
    try:
        args = ap.parse_args(argv)
    except SystemExit as e:
        sys.exit(1 if e.code else 0)
    if args.cmd == "now-doing":
        print(now_doing(args.events, args.progress))
    elif args.cmd == "final":
        print(json.dumps(final(args.events), ensure_ascii=False, sort_keys=True))
    elif args.cmd == "errors":
        for line in errors(args.events):
            print(line)
    elif args.cmd == "stats":
        print(json.dumps(stats(args.events, args.window_min), sort_keys=True))
    else:
        die("usage: events.py now-doing|final|stats ...")


if __name__ == "__main__":
    main(sys.argv[1:])
