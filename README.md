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

## Recommended companion tooling

The plugin works on its own, but the full workflow assumes a few free, open companion tools. `/deen:setup` writes a `Resources/getting-started.md` into your vault with the same guidance and exact install steps.

- **[Obsidian](https://obsidian.md/download)** — open your vault folder as a vault to browse it as a linked knowledge base. Recommended plugin: **TaskNotes**. Database views (**Bases**) are built in.
- **[Superpowers](https://github.com/obra/superpowers)** (Jesse Vincent) — disciplined Claude Code workflows (brainstorm → spec → plan → build, TDD, debugging, code review):
  ```
  /plugin marketplace add anthropics/claude-plugins-official
  /plugin install superpowers@claude-plugins-official
  ```
- **[gstack](https://github.com/garrytan/gstack)** (Garry Tan) — headless-browser QA plus review/ship skills (`/browse`, `/review`, `/ship`, `/office-hours`). Needs Git + [Bun](https://bun.sh):
  ```
  git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup
  ```

How they fit: **Deen** = your context + session continuity · **Superpowers** = how Claude approaches the work · **gstack** = hands-on QA/ship · **Obsidian** = where you read it all.

## Requirements

- Claude Code. `git` is used when present (falls back gracefully). Nothing else is required to run the plugin itself; the tools above are recommended for the full workflow.

## License

MIT
