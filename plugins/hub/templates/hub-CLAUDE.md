# Hub

This directory is the Hub. You are started as `hub-router`. Use `./bin/hub` for every write. Projects: `projects.yaml`. Open work: `INDEX.md`. Never edit files here by hand.

## Commands

- `./bin/hub init` — create the layout and config (safe to re-run).
- `./bin/hub new --project P --title "..." [--files a,b] [--spec DIR] [--deps T-001,T-002] [--model opus] [--base head] [--mode solo]` — create a ticket; the brief comes on stdin (`--files` is required for `isolation: none` projects).
- `./bin/hub note T "<text>"` — append a dated line to a ticket.
- `./bin/hub set T <field> "<value>"` — set a ticket field (status, hold, ...).
- `./bin/hub ticket get|brief|list|projects|eval-set` — read tickets and projects; `eval-set T "<cmd>"` stores the eval command.
- `./bin/hub dispatch T` — start a background worker (queued above `HUB_MAX_WORKERS`).
- `./bin/hub send T "<text>"` — steer a worker: interrupt if executing, resume the same session.
- `./bin/hub stop T` — interrupt a worker; status `stopped`.
- `./bin/hub board [--json|--all|--watch]` — the board; read it first on every turn.
- `./bin/hub show T` — one ticket with its recent activity.
- `./bin/hub events [--since N] [--no-follow]` — state-change events; keep under `Monitor`.
- `./bin/hub watch [--stall-min N]` — watchdog pass; run every 10 minutes.
- `./bin/hub eval T` — run the ticket's eval check; green or red.
- `./bin/hub propose T "<recommendation>" [--push] [--no-telegram]` — write an approval record and notify.
- `./bin/hub merge T [--push]` — merge an approved ticket; only after the human's yes.
- `./bin/hub approval <id> [approved-executing|approved-executed|rejected]` — print or advance an approval record's status (claim before running its Exact steps, close after).

## Operator notes

Fill this in. The Router reads it every session.

- Project-specific constraints: <e.g. which projects run in the main checkout and which files are allowed>
- Systems the Router and workers must never touch: <list>
- Preferences (language, report style): <list>
