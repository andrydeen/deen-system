---
type: reference
tags: [memory, vault, handoff, conventions]
updated: 2026-07-04
---

> **Plugin-owned guide.** This file is written by `/deen:setup` and will be **refreshed** (overwritten) when you re-run setup after a plugin update. Keep your own notes in your own files, not here.

# Memory — what goes where

You have **three memory layers**. Each fact belongs in exactly **one** of them. When you're unsure where something goes, use this table — that's the whole system.

## The what-goes-where table

| You want to keep… | It goes in | Who writes it |
|---|---|---|
| A personal preference or working-style fact ("I prefer tabular diffs", "my email is X") | **Auto-memory** — Claude Code's built-in per-project memory (MEMORY.md + fact files it maintains itself) | Claude, when you say "remember this" |
| Who you are, your business, brand, customers, strategy | **Vault → Context/** — the curated markdown files `/deen:setup` created | You (or Claude, on your instruction), deliberately |
| A durable decision or lesson from today's work session | **Vault → raw/ + wiki/** via `/deen:handoff` at session end | The handoff skill |
| "How is this project built and why" | **The project's own `ARCHITECTURE.md`** in its repo root | Updated by handoff when a session changes the architecture |
| What to do next session in a project | **Vault → wiki/\<Project\>/overview.md** | Rewritten by every handoff save |
| A meeting note, competitor fact, market signal | **Vault → Intelligence/** | You, as it happens |

## The one rule

**One fact, one home.** If you catch yourself pasting the same fact into two layers, stop — pick the row above that matches and delete the copy. Duplicates are how memory systems die: the copies drift, and six months later you don't know which one is true.

## How the layers differ

- **Auto-memory** is Claude's notebook. It's per-project, it loads automatically, and Claude prunes it. Don't curate it by hand — just tell Claude to remember or forget things.
- **The vault** is *your* brain. Nothing lands there unless you (or a skill you invoked) put it there. It's plain markdown you own, readable in Obsidian, and it survives any tool change.
- **Project memory** (`ARCHITECTURE.md` + the handoff wiki) is per-repo state: how the system works, what happened last session, what's next. It's what makes "pick up where I left off" work.

## Daily practice

1. During a session: say "remember this" for preferences; drop business facts into `Context/`.
2. At session end: run `/deen:handoff` — it files the session's decisions and next steps for you.
3. At session start: run `/deen:handoff` again — it reads the overview back and you continue instead of reconstructing.

That's it. The system works when the table above answers "where does this go?" in under five seconds.
