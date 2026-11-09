# hub

A Router plus background workers for Claude Code. You talk to one long-lived
session, the Router. It never does the work: it records each request as a
ticket, starts a headless `claude -p` worker for it (in the project directory
or its own git worktree), watches the workers, verifies results with an eval
command and proposes the merge. You can steer a running worker at any moment,
from the terminal or from Telegram.

## Install

From the marketplace:

```
/plugin marketplace add andrydeen/deen-system
/plugin install hub@deen-system
```

Or load it locally: `claude --plugin-dir plugins/hub`.

## Set up

```
hub init                       # default hub directory: ~/Projects/Hub
hub init --hub-dir /some/dir   # or choose your own
```

`hub init` creates `tickets/`, `.runs/`, `bin/hub`, `config`, `INDEX.md`,
`projects.yaml` and `CLAUDE.md`. It is idempotent and never overwrites existing
files. Edit two of them:

- `projects.yaml`: one entry per project, for example
  ```yaml
  myapp:
    path: /absolute/path/to/myapp
    isolation: worktree   # worktree | none
    main: main
  ```
  `worktree` runs each ticket on its own branch `hub/T-NNN`; `none` runs in the
  main checkout (the ticket must then list its allowed files).
- `CLAUDE.md`, section "Operator notes": your project constraints and systems
  the workers must never touch.

## Start the Router

```
cd ~/Projects/Hub && claude --agent hub-router --permission-mode auto --channels plugin:telegram@claude-plugins-official
```

Omit `--channels ...` to work from the terminal only.

## Daily loop

1. Tell the Router what you want. It writes a ticket (your words verbatim),
   dispatches a worker and confirms in one sentence.
2. Watch the board (`hub board`, or ask). Follow up with `T-14: <words>`; the
   Router sends it to the running worker (`hub send`), which is interrupted and
   resumed in the same session.
3. When a worker reports `ready` and the ticket has an eval, the Router runs it
   itself. Green: it proposes commit / merge / push with a recommendation.
4. Answer `yes T-12` or `approve T-012-1` (terminal, or the configured Telegram
   chat) to run the approved steps, or `reject T-12`. `hold T-14` parks a
   ticket until you lift it.

Text deliverables (scripts, reviews, summaries) come back verbatim. File
deliverables come back as "ready, eval green" plus the absolute path of every
file.

## The four-line report block

Every worker round ends with exactly this, nothing after it:

```
Status: ready | blocked | failed | dropped
Eval: green | red (<first failing line>) | n/a
Files: <absolute path> (new|changed) ; ...   | none
Note: <one sentence: what is unfinished or what the human must decide> | Question: <one question> | none
```

A missing or malformed block sets the ticket to `unknown-report`.

## CLI

| Command | Does |
|---|---|
| `hub new --project P --title "..."` | create a ticket (brief on stdin) |
| `hub note T "<text>"` / `hub set T <field> "<value>"` | record a note / set a field (`status`, `hold`, ...) |
| `hub ticket get\|brief\|list\|projects\|eval-set` | read tickets; `eval-set T "<cmd>"` stores the eval command |
| `hub dispatch T` | start the worker (queued above `HUB_MAX_WORKERS`) |
| `hub send T "<text>"` | steer: SIGINT only while the worker is executing, then resume the same session |
| `hub stop T` | interrupt the worker, status `stopped` |
| `hub board [--json\|--all\|--watch]` | the board |
| `hub show T` | one ticket with recent activity |
| `hub events [--since N] [--no-follow]` | state-change events |
| `hub watch [--stall-min N]` | watchdog: stalled, looping, dead or over-budget workers |
| `hub eval T` | run the ticket's eval check |
| `hub propose T "<rec>" [--push] [--no-telegram]` | write an approval record and notify |
| `hub merge T [--push]` | merge an approved ticket (after the human's yes) |

## Config

`$HUB_DIR/config` holds two values chosen by the delivery spike:

- `WORKER_AGENT_MODE=agent`: workers run with `--agent hub-worker`. The worker
  rules arrive through `--append-system-prompt` (`templates/worker-rules.md`)
  on every round, so `inline` mode behaves identically; `agent` keeps model,
  tools and effort in one profile.
- `EVENT_DELIVERY=monitor`: the Router keeps `hub events` under `Monitor`, so
  events reach its context without polling. `cron` is the fallback
  (`hub board --json` every 5 minutes). Either way `hub watch` runs every 10.

Environment knobs:

| Variable | Default | Meaning |
|---|---|---|
| `HUB_DIR` | `~/Projects/Hub` | hub directory |
| `APPROVALS_DIR` | `~/.deen-system/approvals` | approval records and `config.md` |
| `HUB_MAX_WORKERS` | 4 | concurrent workers; the rest queue |
| `HUB_MAX_TURNS` | 150 | `--max-turns` per round |
| `HUB_MAX_BUDGET_USD` | 8 | `--max-budget-usd` per round |
| `HUB_RETRY_BASE_S` | 30 | base backoff for transient API errors (3 tries) |
| `HUB_EVAL_TIMEOUT_S` | 600 | eval timeout |
| `HUB_TELEGRAM` | 0 | `1` enables Telegram posts |
| `TELEGRAM_ENV_FILE` | `~/.claude/channels/telegram/.env` | bot token file |
| `HUB_TELEGRAM_API` | Telegram Bot API | API base URL override |

## Statuses

Ticket: `open`, `running`, `waiting`, `blocked`, `ready`, `done`, `dropped`,
`hold`, `failed`, `stopped`, `unknown-report`, `conflict`.

Run: `starting`, `queued`, `running`, `finishing`, `retrying N`, `interrupted`,
`exited N`, `stopped`, `failed`.

## Tests

```
bash plugins/hub/tests/run.sh
```

The suite runs against a fake `claude` (`tests/claude`, `tests/fake-claude`),
so it needs no network, account or tokens, and leaves no processes behind.

## Security model

- Workers never commit to main, merge, push, publish or write to an external
  API. They may commit on their own `hub/T-NNN` branch. Only `hub merge`,
  called by the Router after your explicit yes, integrates work.
- Workers and the Router run with `--permission-mode auto`; the Router has no
  Edit, Write or NotebookEdit tools, and workers get a fixed allowed-tool list
  (`--allowedTools "Write,Edit,Read,Glob,Grep"` plus the profile's tools). A
  headless permission denial stops the worker with `blocked`.
- Telegram decisions count only from the chat id configured in
  `$APPROVALS_DIR/config.md` (`telegram_chat_id`); any other sender is ignored
  and reported.
- The bot token is read from `TELEGRAM_ENV_FILE` at send time and never logged
  or written to tickets, events or approval records.
