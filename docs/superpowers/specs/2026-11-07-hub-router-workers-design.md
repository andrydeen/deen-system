# Hub: a router + background workers system on Claude Code

Date: 2026-11-07 · Status: builder-checked, awaiting Din's approval · Owner: Din

## 1. Intent

Din runs many projects in parallel (WillBuilder, OC_Will, FuneralAgency, AI video
such as Helen Cat, personal tooling). Today every piece of work is a separate
Claude Code session that he has to open, feed, watch and remember. He wants one
resident session, the **Router**, that he talks to all day, which dispatches
work to background **Workers** (one per task, each in the right project folder
with that project's own context), tracks every task on a **board**, reports
results back in the Router and in Telegram, and never takes consequential
actions (commit, merge, push, API writes, publishing) without his word.

The pattern comes from DeepSeek Harness's Super-agent essay (2026-10-31) and
`yingpengma/cc-super-agent`, the only tested implementation on Claude Code.
We are building our own small version, not installing either.

### A day with Hub (the scenario this must support)

Morning, one message to the Router: "Run §12–§18 in WillBuilder in parallel,
one worker per section." Then: "Open Helen Cat and write the script for this
scene: …". Then: "Open FuneralAgency, review it and prepare the next step."
Then: "Give me a summary of these four projects."

An hour later Din looks at the board, sees what each worker is doing right now,
notices §14 going wrong, and types in the Router: "T-14: the 14.3 wording is
off, use the v1 phrasing." The §14 worker continues in its own context with
that instruction. When a section is done the Router says: "T-12 ready, eval
green, files: /…/Drafts/12_bodies.xml (new), /…/Conditions.md (changed).
Recommend: commit on the worker branch and merge into main, no push yet. Yes?"
The same message arrives in Telegram when Din is away, and "yes"/"approve" from
Telegram counts.

## 2. Goals, non-goals, anti-goals

**Goals**

- One interaction point. Din talks only to the Router. Workers never talk to him.
- Workers run in parallel, each in its own project directory (and git worktree
  when the project is a git repo), inheriting that project's `CLAUDE.md`,
  handoff context and tools.
- Every task is a ticket on a board that shows status, dependencies, what the
  worker is doing right now, elapsed time and the last report.
- Addressed follow-ups: "T-14: …" goes to that worker's own session, history kept.
- Results come back where Din asked: text answers (scripts, reviews,
  summaries) are delivered in the Router verbatim; file-producing work is
  reported as a four-line report with full paths.
- Git stays with the Router. Workers never commit to main, merge or push.
  The Router proposes commit / merge / push per ticket with a recommendation
  and waits for Din's word.
- Objective "done": where a ticket carries an `eval.md`, the Router runs its
  check itself and reports "ready" only when it is green.
- Watchdog: a stalled, looping or over-budget worker is flagged on the board
  and reported before it says "done".
- Telegram: every "ready / blocked / needs decision" event is also sent to
  Telegram; decisions coming back from Telegram are honoured via the existing
  approval-gate protocol.
- Reusable across projects: the kit ships as a plugin in the `deen-system`
  marketplace; a project only needs a `specs/tickets/` folder for batch work.

**Non-goals (v1)**

- No web page for the board yet (console only; the project-dashboard page is
  phase 3).
- No workers on other machines, no T3 Code, no T3 Connect.
- No experimental agent teams (interactive-only, unusable from `-p`, not needed).
- No event triggers (GitHub, email, CI). Work starts only when Din asks.
- No auto-merge, auto-push, auto-publish. Ever, in any phase.
- No long-term memory / "digital twin" of Din.

**Anti-goals (what would make this a failure even if it technically works)**

- Silent bad work: a worker reports "ready" and the content is wrong. This is
  the number one failure Din named. Everything in §5 (eval, blocked-with-one-
  question, human sign-off for creative work) exists to prevent it.
- A worker touching files outside its ticket, or taking an external action
  (cust06 API write, publish, email) on its own.
- The Router doing the work itself when it gets busy (the documented failure
  of single-session setups).
- Reports without file paths. In six months projects will write files in
  places Din does not know by heart.

## 3. Constraints

- Claude Code 2.1.319 on macOS (zsh). No Linux-only tools (`flock` is not on
  macOS by default; use `mkdir`-based locks or `shlock`/`lockfile` equivalents).
- Existing conventions to reuse, not duplicate: Handoffs wiki
  (`~/Projects/Obsidian/Handoffs/wiki/<Project>/overview.md`, frontmatter `repo:`),
  `approval-gate` skill (`~/.deen-system/approvals/`, Telegram chat_id in its
  `config.md`), the Telegram plugin (`mcp__plugin_telegram_telegram__reply`;
  incoming Telegram messages arrive in the session as channel messages),
  `guardrails` plugin hooks, `project-dashboard` (read-only, parses files).
- Project rules still bind workers: WillBuilder's "API writes to cust06 only on
  Din's go", "commit/push only on Din's go", absolute paths, never echo
  credentials. Workers inherit these from the project `CLAUDE.md` and the
  worker rules repeat the universal ones.
- Verified Claude Code facts (2026-11-07 docs check): `claude --agent <name>`
  with `.claude/agents/<name>.md` (fields: `tools`, `disallowedTools`, `model`,
  `effort`, `permissionMode`, `maxTurns`, `autoCompactWindow`, `isolation`,
  `background`, `memory`); `--permission-mode` values `default | acceptEdits |
  plan | auto | dontAsk | bypassPermissions`; `claude -p` with `--session-id`,
  `--resume`, `--append-system-prompt`, `--output-format stream-json --verbose`,
  `--max-turns`, `--max-budget-usd`; `claude --bg` sessions with
  `claude agents --json`, `attach`, `logs`, `stop`; `SendMessage` resumes a
  named subagent; tools `Monitor`, `CronCreate` (session-scoped, 7-day expiry),
  hooks `SubagentStop`, `Stop`, `Notification`.
- Unverified, must be settled by the spike (§8): `-p` combined with `--agent`;
  whether a Router `disallowedTools: Edit, Write` leaks into spawned processes
  (irrelevant if workers are separate `claude -p` processes, which is the plan);
  whether `Monitor` can deliver "ticket changed" lines into the Router reliably
  for a whole day (fallback: `CronCreate` polling every 5 minutes).

## 4. Shape of the system

```
Din ── terminal ──┐
Din ── Telegram ──┤
                  ▼
            ┌──────────┐   hub dispatch / send / board / eval / merge / watch
            │  Router  │ ───────────────────────────────┐
            │ (session)│                                │
            └──────────┘                                ▼
                  ▲                 ┌───────────────────────────────────┐
                  │  reports,       │ Workers: `claude -p` processes,   │
                  │  board lines    │ one per ticket, in the project    │
                  └──────────────── │ dir / its own git worktree        │
                                    └───────────────────────────────────┘
                                                 │
                                    ~/Projects/Hub/  (tickets, runs, INDEX)
```

**Hub directory** `~/Projects/Hub/` (private git repo, never public):

```
Hub/
├── CLAUDE.md            # loads the Router rules from the plugin
├── projects.yaml        # registry: name → path, type (git | folder), notes
├── INDEX.md             # one line per open ticket (the Router reads it every turn)
├── tickets/
│   └── T-014-willbuilder-s14.md   # brief, project, mode, deps, hold, reports log
└── .runs/
    └── T-014/           # session-id, status, pid, events.jsonl, progress.log,
                         # report.md, pending/ (queued follow-ups), worktree path
```

**Plugin** `hub` in `~/Projects/Deen-setup/deen-system/plugins/hub/`:

```
plugins/hub/
├── agents/hub-router.md     # the Router agent (started with `claude --agent hub-router`)
├── agents/hub-worker.md     # worker agent profile (model, tools, effort)
├── templates/worker-rules.md  # appended to every worker's system prompt
├── templates/brief.md       # how the Router writes a brief
├── skills/hub-ticket/       # interview → specs/tickets/<nn>_<name>/{rd,eval}.md + board.md
├── scripts/hub              # single CLI: dispatch | send | board | show | eval | merge | stop | watch | import
└── README.md
```

### Components

**Router** (`agents/hub-router.md`): model Sonnet 5.5 (my call: DeepSeek and
cc-super-agent both found a lighter model is enough because the Router never
does the work; override to Opus if its judgement proves thin), effort medium,
`disallowedTools: Edit, Write, NotebookEdit`, started with
`claude --agent hub-router --permission-mode auto --channels plugin:telegram@claude-plugins-official`
from `~/Projects/Hub`. Because one bot token can be long-polled by one process,
the Router is the single Telegram inbox for the whole machine (Din's
decision): every inbound Telegram message lands in the Router, and the Router
runs the approval-gate RESOLVE protocol for any pending approval id, not only
Hub tickets. Other unattended sessions keep sending via the same bot; they no
longer need to receive.
Rules (the essence; full text lives in the agent file):

1. You only talk, record, dispatch and verify. You never do the work. The one
   exception is a lookup that needs no judgement (list a directory, read a
   report file).
2. Every incoming message is new work, a follow-up to a ticket, or neither.
   It is a follow-up only when it names a ticket ("T-14: …") or exactly one
   open ticket fits the reference. Otherwise it is new work.
3. New work: write the ticket file and its `INDEX.md` line first, then run
   `hub dispatch`. Confirm in one sentence naming project, object and the
   intended result.
4. Briefs quote Din's words verbatim and add only routing facts (project path,
   earlier decisions, holds, constraints). No plans, no invented acceptance
   criteria. For spec tickets the brief points at `rd.md` and `eval.md`.
5. Follow-ups: `hub send T-014 "<words>"`. Record the command in the ticket file.
6. Holds: "hold T-14" is recorded with Din's words and the lift condition,
   repeated in every later brief, and lifted only by a clear message from Din.
7. On every turn read `INDEX.md` and any ⚠ lines. Update records in the same
   turn as each event.
8. When a worker reports `ready` on a ticket with `eval.md`: run `hub eval`
   yourself. Report "ready" only when it is green. Red → send the failure to
   the same worker as a follow-up.
9. Report to Din only for: a usable result, a decision he must make, or work
   that cannot be finished. Lead with the conclusion. Rewrite worker reports,
   never forward them raw, except text deliverables (scripts, reviews,
   summaries), which are delivered verbatim.
10. Git: after "ready", propose commit / merge / push for that ticket with a
    recommendation and wait. Execute only via `hub merge` after Din's yes.
    Never push, never touch cust06 or any external system without his word.
11. Every report that concerns files lists the absolute path of every created
    or changed file.
12. Mirror every "ready / blocked / needs decision / ⚠" event to Telegram
    (one message, ≤ 100 words). Decisions arriving from Telegram are valid
    only from the configured chat_id (approval-gate rule).

**Worker** (`agents/hub-worker.md` + `templates/worker-rules.md`): model Opus
5.5 by default, per-ticket `model:` override (Fable for hard tickets, Sonnet
for summaries), effort medium, `--permission-mode auto`, `--max-turns` and
`--max-budget-usd` set per ticket (defaults 150 turns / $8). Rules:

- One ticket, one project directory (or its worktree). Never leave it. Never
  edit files the ticket does not name when `rd.md` lists allowed paths.
- Nobody watches you live. Carry local work through to a verified result. Stop
  with `blocked` and exactly one question when a decision belongs to Din;
  the deciding factor is impact, not edit size.
- Honour holds. Rounds can be interrupted by Din at any moment (`hub send`
  sends SIGINT and resumes you with a new instruction). The first action of a
  resumed round is always to read `progress.log` and `git status` and state in
  one line what is already done before continuing. Never repeat a completed step.
- A permission denial in headless mode is not something to work around: stop
  with `blocked` and name the tool and path you needed.
- Never commit to main, merge, push, write to an external API, publish or send
  anything. Committing on your own branch is allowed and encouraged as a
  checkpoint.
- After every meaningful step append one line to `progress.log`:
  `HH:MM  <what you are doing now>`.
- End every round with exactly this block and nothing after it:

  ```
  Status: ready | blocked | failed | dropped
  Eval: green | red (<first failing line>) | n/a
  Files: <absolute path> (new|changed) ; …   | none
  Note: <one sentence: what is unfinished or what Din must decide> | Question: <one question> | none
  ```

**`hub` CLI** (`scripts/hub`, bash + a little Python 3, no dependencies):

| Command | Does |
|---|---|
| `hub dispatch T-014` | Creates `.runs/T-014/`, the worktree (`git worktree add -b hub/T-014 <repo>/.claude/worktrees/T-014 <base>` when the project's `projects.yaml` entry says `isolation: worktree`; `base` = `main` unless the ticket says `base: head`; projects with `isolation: none`, such as WillBuilder, run in the main checkout and the ticket must list its allowed files), then runs the worker round in the background: `claude -p "<brief>" --agent hub-worker --session-id <uuid> --append-system-prompt "<worker-rules>" --permission-mode auto --output-format stream-json --verbose --max-turns N --max-budget-usd X`, cwd = worktree or project dir, stdout → `events.jsonl`. Extracts the final block into `report.md` and `status`. Concurrency cap `HUB_MAX_WORKERS` (default 4) with a queue. Retries transient API errors with backoff (3 tries). |
| `hub send T-014 "<text>"` | Live steering (Din's decision). If a round is running: SIGINT it (clean turn end), wait for exit, then start a new round with `--resume <session-id>` whose prompt is "Interrupted by Din. Before anything else read progress.log and `git status` to see what is already done. New instruction: <text>". If no round is running: start the resumed round directly. Rounds never overlap for one ticket; a second `send` during the restart is queued in `pending/`. |
| `hub board [--watch] [--json]` | The console board: ID · project · title · status · mode · deps · now-doing (last `progress.log` line or last tool call from `events.jsonl`) · elapsed · last report line · flags (⚠ stalled, ⚠ loop, ⏸ hold, 💰 budget). `--watch` refreshes every 5 s. `--json` feeds phase 3. |
| `hub show T-014` | Full ticket: brief, all follow-ups, progress log, last 30 tool calls, report, worktree path, branch. |
| `hub eval T-014` | Runs the fenced `check` block from the ticket's `eval.md` inside the worktree; prints green/red and the first failing lines; writes result into the ticket. |
| `hub merge T-014 [--push]` | Worktree tickets: commits uncommitted work on the worker branch, merges main into the branch, re-runs `hub eval` (ready means green on the integrated state), then `git merge --no-ff hub/T-014` into main, removes the worktree, optional push. Conflicts or a red re-eval → stops and tells the Router to send the failure back to the worker. `isolation: none` tickets: commits the ticket's allowed files on the main branch, optional push. Only the Router calls this, only after Din's yes. |
| `hub new` / `hub note T-014 "<text>"` | The Router's only write path: `hub new` creates a ticket file and its `INDEX.md` line from a brief on stdin; `hub note` appends a dated line (follow-up sent, hold, decision, report) to the ticket file. The Router has no Edit/Write tools. |
| `hub propose T-014 "<commit|merge|push recommendation>"` | Writes an approval record `~/.deen-system/approvals/T-014-<n>.md` (approval-gate format, `## Exact steps` = the `hub merge` command) and prints the Telegram line. Resolved by "yes T-14" / "approve T-14-1" from the terminal or Telegram; a bare "yes" is accepted only when exactly one proposal is pending. |
| `hub stop T-014` | SIGINT to the round (clean turn end), status `stopped`. |
| `hub watch` | The watchdog pass: for every running ticket, flag stalled (no event for 15 min), loop (same file edited > 8 times in 30 min, or the same tool call repeated > 10 times), over budget, dead process. Writes ⚠ into `INDEX.md` and prints one line per flag. Run by the Router via `CronCreate` every 10 min; also callable by hand. |
| `hub import <repo>` | Reads `<repo>/specs/tickets/board.md`, creates one hub ticket per `ready` spec ticket with its deps and mode, skips ones already imported. |
| `hub events` | Tails state changes (`ready`, `blocked`, `⚠`) as single lines; the Router keeps it under `Monitor` so events arrive in its context without polling. Falls back to the cron if Monitor proves unreliable (spike §8). |

**Tickets.** Two kinds, one board:

- *Ad-hoc* (script, review, summary, "fix X"): the Router creates
  `tickets/T-0nn-<slug>.md` from Din's words. Fields: project, path, model,
  mode (`solo`), deps, hold, brief (verbatim), reports log.
- *Spec* (batch work like §12–§18): lives in the project repo as
  `specs/tickets/<nn>_<name>/rd.md` (what, allowed files, forbidden files,
  decisions made) and `eval.md` (a fenced `check` block with a command that
  exits non-zero on failure, plus manual checks), with `specs/tickets/board.md`
  (ID · status draft/ready/done · mode · runs alongside / waits on). Created by
  the `hub-ticket` interview skill, imported with `hub import`. Hub ticket
  status flows: `open → running → (waiting | blocked) → ready → done | dropped`,
  plus `hold`.

**Board, phase 3**: a `/hub` route in `project-dashboard` that reads
`hub board --json` output (exported to `~/Projects/Hub/board.json` on every
state change) and renders the same columns, with a ticket drawer showing
`hub show`. Read-only, like the rest of the dashboard.

## 5. Quality: how "ready" is earned

1. **Eval is code.** Spec tickets are ready only when `hub eval` is green, run
   by the Router, not trusted from the worker. For WillBuilder the check
   script wraps what already exists: balanced-IF and cp1252 checks from the
   generators, field-name and lookup-row verification via the BizNet API
   (read-only), no-duplicate-clause-across-sections, file present at the
   declared path.
2. **Workers do not guess.** Missing decision → `blocked` + one question. The
   Router relays it; Din's answer goes back as a follow-up.
3. **Creative and analytical deliverables are judged by Din.** Scripts,
   reviews, summaries have `Eval: n/a`; the Router delivers the text and marks
   the ticket `ready`, and Din says done (or sends a follow-up).
4. **The board shows drift early.** `now-doing`, elapsed, repeated-file and
   silence flags are visible before any "ready".

## 6. Decisions already made (as Din made them)

- Follow-ups go through the Router with an explicit ticket address, not by
  attaching to the worker. `claude attach` / reading `.runs/` directly remains
  an emergency debugging path, not a working path.
- Workers never commit to main, merge, push, write to cust06 or any external
  system. The Router proposes, Din decides, `hub merge` executes.
- Text deliverables are returned verbatim in the Router; file deliverables are
  reported with absolute paths and the eval result.
- Both terminal and Telegram are first-class: every event Din needs goes to
  both; Telegram decisions are honoured.
- Board detail must show what a worker is doing now, not just a status.
- The kit is reusable and lives in `deen-system`; v1 is console-first.
- Follow-ups interrupt the running round and resume the worker with the new
  instruction (live steering), rather than waiting for the round to end.
- The Router is the single Telegram inbox and the resolver for all
  approval-gate ids on this machine.

## 7. Decisions I made (my calls, open to override)

- WillBuilder runs with `isolation: none`: its `CLAUDE.md` forbids worktrees
  and every section lives in one `WillWriter.xml`, so branches would only
  produce conflicts. Workers there write only their section's draft file
  (`final project files/WillWriter/Drafts/<section>_bodies.xml`, the existing
  convention) plus their Conditions lines; assembling or pushing into the
  Writer stays a separate, Din-triggered step. `projects.yaml` carries the
  `isolation` flag per project; git projects default to `worktree`.
- "Ready" is judged on the integrated state: `hub merge` merges main into the
  worker branch and re-runs eval before merging back.
- A permission denial under `auto` in headless mode becomes `blocked` with a
  question; no `acceptEdits` or `bypassPermissions` fallback.
- All Router writes go through `hub new` / `hub note` / `hub propose`; its
  Bash is not otherwise restricted in v1 (rule-based), to be tightened to a
  `hub *` plus read-only allowlist if the Router is ever caught doing work.
- Commit / merge / push proposals are approval-gate records with ids, so the
  terminal and Telegram resolve the same object; bare "yes" only when exactly
  one proposal is pending.
- Workers are separate `claude -p` processes managed by a script (the
  cc-super-agent model), not in-session subagents: a process can be resumed,
  stopped, logged and inspected independently of the Router, and the Router's
  context does not grow with worker output.
- Router on Sonnet 5.5, workers on Opus 5.5, per-ticket override.
- Worktrees branch from `main` by default (`base: head` opt-in), under
  `<repo>/.claude/worktrees/<ticket>` to match Claude Code's own convention.
- Permission mode `auto` for workers, never `bypassPermissions`.
- Default limits: 4 concurrent workers, 150 turns, $8 per ticket round;
  watchdog thresholds 15 min silence, 8 edits of one file in 30 min.
- Locks via `mkdir` (atomic on macOS), not `flock`.
- Telegram messages are capped at 100 words (DeepSeek's IM rule).
- The Router's own context: `autoCompactWindow` is ignored under `--agent`, so
  the Router keeps its context small by rule (read files, do not paste them;
  rewrite reports) and Din restarts it daily; INDEX.md and ticket files are the
  memory, not the conversation.

## 8. Phase 0: the spike (hello-signal, throwaway)

Before any real code, a half-day spike in a scratch repo answers the unverified
questions with a red → green lamp each:

1. `claude -p "…" --agent hub-worker --session-id X --output-format stream-json --verbose` from a worktree: does `--agent` apply under `-p`, do tool events stream, does the final block parse? Then `--resume X` with a follow-up: is history kept? Then SIGINT a running round mid-tool-call and `--resume X` again: does the session resume cleanly and does the worker see its own partial work?
2. A worker given a ticket naming one allowed file: does it stay inside it under `--permission-mode auto`?
3. Router session running `Monitor` on a script that prints a line when a file changes: does the line arrive in the Router's context, and does it survive 30 minutes? If not, `CronCreate` every 5 min.
4. From a Router session started with `--channels plugin:telegram@claude-plugins-official`: send one Telegram message via the plugin, and receive one reply as a channel message (the plugin failed to connect in the research session; confirm it connects in a fresh one). Confirm that an unattended second session can still *send* via the same bot while the Router holds the channel.

Spike results go back into this document before the plan is written.

**Spike result (2026-11-08):** `WORKER_AGENT_MODE=agent`, `EVENT_DELIVERY=PENDING_E_VALUE`. Lamps A, B, C, D green; Telegram sending from a second process green via Bot API, inbound half deferred to the first Router start. Two corrections to the worker contract: add `--allowedTools "Write,Edit,Read,Glob,Grep"` (the auto classifier denied a burst of parallel edits), and recognise interruption by a marker, not the exit code (SIGINT → exit 0, `result.subtype=error_during_execution`). Details: `docs/superpowers/specs/2026-11-07-hub-spike-results.md`.

## 9. Phases (minimal v1)

- **Phase 1 — Hub core, used end to end on one real ticket.** Plugin skeleton,
  Router and Worker agents, worker rules, `hub dispatch / send / board / show /
  eval / stop / watch / events`, ad-hoc tickets, Telegram mirror. Exit test:
  the §12 bodies ticket in WillBuilder runs as a worker in the main checkout
  (`isolation: none`), writing only `Drafts/12_bodies.xml` and its Conditions
  lines; Din interrupts it once with an addressed follow-up and it resumes
  correctly; eval goes green; the Router proposes the commit, it is resolved
  with "yes T-12" from Telegram, and `hub merge` commits; the same events
  arrived in Telegram. A second, throwaway git project with
  `isolation: worktree` proves the branch + merge path in the same phase.
- **Phase 2 — Batch work.** `hub-ticket` interview skill, `specs/tickets/`
  format, `hub import`, dependency-aware dispatch (`waits on`), `hub merge`
  conflict path, WillBuilder eval script. Exit test: §13–§18 run as parallel
  workers from one morning message.
- **Phase 3 — Board page.** `/hub` route in project-dashboard from
  `board.json`. Exit test: Din finds a drifting worker from the page.

Later (captured, not planned): event triggers, remote workers, a merge worker
for conflicts, per-project eval libraries for AI video and FuneralAgency.

## 10. What is left to the builder

- Exact Router and Worker prompt wording (follow §4 rules; keep both under
  ~120 lines).
- `stream-json` parsing details for `now-doing` and the final block.
- Queue, lock and retry implementation in `scripts/hub`.
- Board column widths and colouring; `--watch` implementation.
- Where `projects.yaml` is seeded from (suggest: generate once from
  `Handoffs/index.md` + overview `repo:` frontmatter, then hand-maintain).
- Test strategy per the Red Lamp rule: every `hub` subcommand gets a
  reproducible shell check in `plugins/hub/tests/`.
