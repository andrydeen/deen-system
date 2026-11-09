#!/usr/bin/env python3
"""Ticket files, INDEX.md regeneration and the project registry. Stdlib only."""
import argparse
import contextlib
import fcntl
import glob
import json
import os
import re
import sys
import tempfile
import time

LIST_KEYS = ("deps", "files")
SKIP_KEYS = ("brief", "eval_check", "log")


def hub_dir():
    return os.environ.get("HUB_DIR") or os.path.expanduser("~/Projects/Hub")


def now():
    return time.strftime("%Y-%m-%dT%H:%M")


def die(msg):
    sys.stderr.write("hub: %s\n" % msg)
    sys.exit(1)


def atomic_write(path, text):
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".tmp-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


@contextlib.contextmanager
def flock(name):
    """Exclusive advisory lock on a sidecar file (the ticket file itself is replaced
    atomically, so its inode cannot carry a lock)."""
    d = os.path.join(hub_dir(), ".locks")
    os.makedirs(d, exist_ok=True)
    fd = os.open(os.path.join(d, name), os.O_RDWR | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def ticket_path(ticket_id):
    hits = sorted(glob.glob(os.path.join(glob.escape(hub_dir()), "tickets", "%s-*.md" % glob.escape(ticket_id))))
    if not hits:
        die("unknown ticket: %s" % ticket_id)
    return hits[0]


def all_ids():
    ids = []
    for p in glob.glob(os.path.join(glob.escape(hub_dir()), "tickets", "T-*.md")):
        m = re.match(r"(T-\d+)-", os.path.basename(p))
        if m:
            ids.append(m.group(1))
    return sorted(ids, key=lambda i: int(i[2:]))


def next_id():
    nums = [int(i[2:]) for i in all_ids()]
    return "T-%03d" % ((max(nums) if nums else 0) + 1)


def parse_list(v):
    v = v.strip()
    if v.startswith("[") and v.endswith("]"):
        v = v[1:-1]
    return [x.strip() for x in v.split(",") if x.strip()]


def fmt_value(key, val):
    if isinstance(val, (list, tuple)):
        return "[%s]" % ", ".join(str(x) for x in val)
    return str(val).replace("\n", " ")


def split_file(text):
    """Return (frontmatter_lines, body) of a ticket file."""
    lines = text.split("\n")
    if not lines or lines[0] != "---":
        return [], text
    for i in range(1, len(lines)):
        if lines[i] == "---":
            return lines[1:i], "\n".join(lines[i + 1:])
    return [], text


def parse_frontmatter(lines):
    fm = {}
    key = None
    for line in lines:
        m = re.match(r"^([A-Za-z_][\w-]*):\s?(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2).strip()
            if key in LIST_KEYS:
                fm[key] = parse_list(val) if val else []
            else:
                fm[key] = val
        elif key is not None and re.match(r"^\s*-\s+", line):
            if not isinstance(fm.get(key), list):
                fm[key] = []
            fm[key].append(re.sub(r"^\s*-\s+", "", line).strip())
    return fm


def parse_body(body):
    brief, eval_check, log = "", None, []
    i = body.rfind("\n## Log")
    log_part = ""
    if i >= 0:
        log_part = body[i + len("\n## Log"):]
        body = body[:i]
    j = body.rfind("\n## Eval")
    eval_part = ""
    if j >= 0:
        eval_part = body[j + len("\n## Eval"):]
        body = body[:j]
    k = body.find("## Brief")
    if k >= 0:
        brief = body[k + len("## Brief"):].strip("\n")
    m = re.search(r"```check[^\n]*\n(.*?)\n```", eval_part, re.S)
    if m:
        eval_check = m.group(1)
    log = [l for l in log_part.split("\n") if l.strip()]
    return brief, eval_check, log


def load(ticket_id):
    with open(ticket_path(ticket_id), encoding="utf-8") as f:
        text = f.read()
    fm_lines, body = split_file(text)
    fm = parse_frontmatter(fm_lines)
    fm["brief"], fm["eval_check"], fm["log"] = parse_body(body)
    return fm


def save(ticket_id, fm):
    path = ticket_path(ticket_id)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    _, body = split_file(text)
    out = ["---"]
    for k, v in fm.items():
        if k in SKIP_KEYS:
            continue
        out.append("%s: %s" % (k, fmt_value(k, v)))
    out.append("---")
    atomic_write(path, "\n".join(out) + "\n" + body)


def regen_index():
    with flock("INDEX.lock"):
        _regen_index()


def _regen_index():
    lines = ["# Hub index", ""]
    for tid in all_ids():
        fm = load(tid)
        if fm.get("status") in ("done", "dropped"):
            continue
        deps = fm.get("deps") or []
        hold = fm.get("hold") or "none"
        flag = "⚠ " if fm.get("flag") else ""
        lines.append("- %s%s · %s · %s · %s · deps: %s · hold: %s" % (
            flag, tid, fm.get("project", ""), fm.get("title", ""),
            fm.get("status", ""), ", ".join(deps) if deps else "none", hold))
    atomic_write(os.path.join(hub_dir(), "INDEX.md"), "\n".join(lines) + "\n")


def unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        return v[1:-1]
    return v


def strip_comment(v):
    """Drop an unquoted trailing ' #...' comment."""
    q = None
    for i, c in enumerate(v):
        if q:
            if c == q:
                q = None
        elif c in "\"'" and (i == 0 or v[i - 1].isspace()):
            q = c
        elif c == "#" and (i == 0 or v[i - 1].isspace()):
            return v[:i].rstrip()
    return v.rstrip()


def projects():
    res = {}
    cur = None
    path = os.path.join(hub_dir(), "projects.yaml")
    if not os.path.exists(path):
        return res
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if not line[0].isspace():
                m = re.match(r"^([^:\s][^:]*):\s*$", strip_comment(line))
                if m:
                    cur = unquote(m.group(1))
                    res[cur] = {}
                else:
                    cur = None
            elif cur is not None:
                m = re.match(r"^\s+([^:\s][^:]*):\s*(.*)$", line)
                if m:
                    res[cur][m.group(1).strip()] = unquote(strip_comment(m.group(2)))
    return res


def slugify(title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")[:40].strip("-")
    return s or "ticket"


def render_template(values):
    tpl = os.path.join(os.environ.get("HUB_PLUGIN_ROOT")
                       or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."),
                       "templates", "ticket.md")
    with open(tpl, encoding="utf-8") as f:
        text = f.read()
    return re.sub(r"\{\{([A-Z]+)\}\}", lambda m: values.get(m.group(1), ""), text)


def cmd_new(argv):
    ap = argparse.ArgumentParser(prog="hub new")
    ap.add_argument("--project", required=True)
    ap.add_argument("--title", required=True)
    ap.add_argument("--mode", default="solo")
    ap.add_argument("--model", default="")
    ap.add_argument("--deps", default="")
    ap.add_argument("--files", default="")
    ap.add_argument("--spec", default="")
    ap.add_argument("--base", default="")
    ap.add_argument("--max-turns", default="")
    ap.add_argument("--max-budget-usd", default="")
    a = ap.parse_args(argv)
    proj = projects().get(a.project)
    if proj is None:
        die("unknown project: %s" % a.project)
    if proj.get("isolation", "worktree") == "none" and not parse_list(a.files):
        die("--files is required for isolation: none projects")
    if a.max_turns and not re.match(r"^[1-9][0-9]*$", a.max_turns):
        die("--max-turns must be a positive integer")
    if a.max_budget_usd and not re.match(r"^[0-9]+(\.[0-9]+)?$", a.max_budget_usd):
        die("--max-budget-usd must be a number")
    brief = sys.stdin.read()
    if brief.endswith("\n"):
        brief = brief[:-1]
    tid = next_id()
    created = now()
    title = a.title.replace("\n", " ")
    values = {
        "ID": tid, "PROJECT": a.project, "PATH": proj.get("path", ""), "TITLE": title,
        "STATUS": "open", "MODE": a.mode, "ISOLATION": proj.get("isolation", "worktree"),
        "MODEL": a.model, "DEPS": fmt_value("deps", parse_list(a.deps)),
        "FILES": fmt_value("files", parse_list(a.files)), "HOLD": "none",
        "BASE": a.base or proj.get("main", "main"), "CREATED": created, "SPEC": a.spec,
        "MAXTURNS": a.max_turns, "MAXBUDGET": a.max_budget_usd,
        "BRIEF": brief,
    }
    out = render_template(values)
    if not out.endswith("\n"):
        out += "\n"
    path = os.path.join(hub_dir(), "tickets", "%s-%s.md" % (tid, slugify(title)))
    atomic_write(path, out)
    regen_index()
    print(tid)


def cmd_note(argv):
    if len(argv) != 2:
        die("usage: note <ticket> <text>")
    path = ticket_path(argv[0])
    with flock(argv[0] + ".lock"):
        with open(path, encoding="utf-8") as f:
            text = f.read()
        text = text.rstrip("\n") + "\n- %s %s\n" % (now(), argv[1].replace("\n", " "))
        atomic_write(path, text)


def cmd_set(argv):
    if len(argv) != 3:
        die("usage: set <ticket> <key> <value>")
    tid, key, val = argv
    ticket_path(tid)
    with flock(tid + ".lock"):
        fm = load(tid)
        fm[key] = parse_list(val) if key in LIST_KEYS else val
        save(tid, fm)
    regen_index()


def cmd_eval_set(argv):
    if len(argv) != 2:
        die("usage: eval-set <ticket> <command>")
    tid, cmd = argv
    if "```" in cmd:
        die("eval command must not contain a ``` fence")
    path = ticket_path(tid)
    with flock(tid + ".lock"):
        with open(path, encoding="utf-8") as f:
            text = f.read()
        ms = list(re.finditer(r"^## Eval[ \t]*$", text, re.M))
        if not ms:
            die("ticket has no ## Eval section: %s" % tid)
        m = ms[-1]
        rest = text[m.end():]
        n = re.search(r"\n## ", rest)
        old, after = (rest[:n.start()], rest[n.start() + 1:]) if n else (rest, "")
        old = re.sub(r"```check[^\n]*\n.*?\n```\n?", "", old, count=1, flags=re.S).strip("\n")
        block = "\n\n```check\n%s\n```\n" % cmd
        if old:
            block += "\n" + old + "\n"
        if after:
            block += "\n"
        atomic_write(path, text[:m.end()] + block + after)


def cmd_get(argv):
    if not argv:
        die("usage: get <ticket> [key]")
    fm = load(argv[0])
    for k in SKIP_KEYS:
        fm.pop(k, None)
    if len(argv) > 1:
        v = fm.get(argv[1], "")
        print(",".join(v) if isinstance(v, list) else v)
    else:
        print(json.dumps(fm, ensure_ascii=False))


def cmd_list(argv):
    status = None
    if argv[:1] == ["--status"] and len(argv) > 1:
        status = argv[1]
    for tid in all_ids():
        if status is None or load(tid).get("status") == status:
            print(tid)


def main(argv):
    if not argv:
        die("usage: tickets.py new|note|set|get|brief|list|projects ...")
    sub, rest = argv[0], argv[1:]
    if sub == "new":
        cmd_new(rest)
    elif sub == "note":
        cmd_note(rest)
    elif sub == "set":
        cmd_set(rest)
    elif sub == "eval-set":
        cmd_eval_set(rest)
    elif sub == "get":
        cmd_get(rest)
    elif sub == "brief":
        if not rest:
            die("usage: brief <ticket>")
        print(load(rest[0])["brief"])
    elif sub == "list":
        cmd_list(rest)
    elif sub == "projects":
        print(json.dumps(projects(), ensure_ascii=False))
    else:
        die("ticket: unknown subcommand: %s" % sub)


if __name__ == "__main__":
    main(sys.argv[1:])
