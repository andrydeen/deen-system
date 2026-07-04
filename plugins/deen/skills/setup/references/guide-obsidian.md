---
type: reference
tags: [obsidian, vault, knowledge]
updated: 2026-07-04
---

> **Plugin-owned guide.** Written by `/deen:setup`; **refreshed** (overwritten) when you re-run setup after a plugin update. Keep personal notes elsewhere.

# Obsidian — where you read what the system writes

Claude Code and the handoff skill *write* your vault; Obsidian is where you *read* it. Without a reading habit, the vault becomes a write-only archive — notes pile up that nobody sees, and the system quietly dies. Two minutes of reading a day keeps it alive.

## The daily loop (the reason to bother)

- **Morning, before starting a project:** open `wiki/<Project>/overview.md` — yesterday's state and today's next steps, already written for you.
- **When something feels familiar:** search the vault. The pattern you're about to reinvent is probably in `wiki/<Project>/patterns.md` or a raw note.
- **Weekly, five minutes:** skim `log.md`. It's a one-line-per-session history of everything you've done — surprisingly good for standups and invoices.

Obsidian's graph view also shows how your projects, patterns, and context files connect — that's when the "second brain" framing stops being a metaphor.

## Setup (one time)

1. Install Obsidian from [obsidian.md](https://obsidian.md) (free).
2. **Open your vault folder as a vault:** *Open folder as vault* → choose the folder `/deen:setup` created (default `~/Deen-OS`).
3. That's it. Opening the folder creates a `.obsidian/` directory inside your vault — that's normal (and it's exactly what `/deen:verify` checks to mark this area green).

Recommended extras (optional): the **TaskNotes** community plugin; the built-in **Bases** database views for `Intelligence/`.

## Ground rules

- Obsidian **views** the vault; it doesn't own it. Everything is plain markdown on disk — you can grep it, sync it, or leave Obsidian entirely and lose nothing.
- Don't reorganize the folder structure from inside Obsidian — the skills expect the layout `/deen:setup` created (`Context/`, `Projects/`, `raw/`, `wiki/`, …).
- Your vault is **yours**: it contains your business context. Keep it out of shared repos (setup already wrote a `.gitignore` that helps).
