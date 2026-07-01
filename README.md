# Deen System

A Claude Code plugin that gives you two things:

- **`/deen:setup`** — bootstraps a personal "Deen OS" context vault (a structured set of markdown files about you, your business, brand, customers, and strategy) and interviews you to fill it in.
- **`/deen:handoff`** — saves a compact note at the end of a work session and restores context at the start of the next one, so any project can be picked back up cleanly.

Everything lives in plain markdown you own. Obsidian is optional (nice for viewing, not required).

## Install

```
/plugin marketplace add andrydeen/deen-system
/plugin install deen@deen-system
```

Then, in any project:

```
/deen:setup     # first time: build and personalize your vault
/deen:handoff   # end of a session: save state · start of a session: restore it
```

## What `/deen:setup` creates

A vault (default `~/Deen-OS`) with:

- `Context/` — `me`, `business`, `services`, `brand`, `icp`, `pain-points`, `strategy`, `team`, `infrastructure`
- `Projects/`, `Daily/`, `Resources/`, `Skills/`, `Intelligence/`
- A routing `CLAUDE.md` in every folder so Claude always knows where information belongs

It also writes `~/.deen-system/config.md` (your name, vault path) that `/deen:handoff` reads.

## What `/deen:handoff` does

- **End of session:** writes `raw/<Project>/YYYY-MM-DD.md`, refreshes `wiki/<Project>/overview.md`, appends patterns/log, and updates `ARCHITECTURE.md` when the session changed the architecture.
- **Start of session:** reads the overview and summarizes where you left off.

## Requirements

- Claude Code. `git` is used when present (falls back gracefully). Nothing else is required.

## License

MIT
