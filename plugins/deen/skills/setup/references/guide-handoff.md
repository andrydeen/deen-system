---
type: reference
tags: [handoff, sessions, continuity]
updated: 2026-07-04
---

> **Plugin-owned guide.** Written by `/deen:setup`; **refreshed** (overwritten) when you re-run setup after a plugin update. Keep personal notes elsewhere.

# Handoff — never lose a session again

The handoff habit is two commands a day:

- **End of a work session:** `/deen:handoff` → saves a compact note of what you built, decided, and what's next.
- **Start of the next session:** `/deen:handoff` → reads the state back and summarizes where you left off.

That's the whole discipline. What it buys you: no more "what were we doing?" at session start, and a vault that slowly becomes a searchable history of every project.

## What actually gets written

| File in your vault | What it is | Lifecycle |
|---|---|---|
| `raw/<Project>/YYYY-MM-DD.md` | the day's session note | immutable once written |
| `wiki/<Project>/overview.md` | current project state ("what's done / next") | rewritten every save |
| `wiki/<Project>/patterns.md` | reusable patterns you found | append-only |
| `log.md` | one line per session — plus a `restored:` line whenever you restore | append-only |

## The round-trip — why two real sessions matter

A handoff has only proven itself when a note saved in **one session** is restored in a **genuinely new session** (you ended the first one — a real session boundary, not a save-then-read in the same sitting). The restore appends a `restored:` line to `log.md`; `/deen:verify` looks for a save dated *before* a restore to mark your handoff area green. So to get verified: work, save, end the session, start a fresh one, restore.

## Precedence rule — if you already have your own handoff skill

This handoff triggers **only** on `/deen:handoff` or "deen …"-phrases ("deen wrap up", "deen restore context") — never on bare words like "handoff" or "wrap up". If you run your own separate handoff skill, the two never compete: generic phrases go to yours, `deen`-qualified ones come here, and your notes land in exactly one place per command. Pick one system as your daily default and stay with it.

## Turning it off

Set `handoff_enabled: false` in `~/.deen-system/config.md` and the skill does nothing, silently. Flip it back anytime.
