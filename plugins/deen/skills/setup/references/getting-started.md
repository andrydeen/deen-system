---
type: reference
tags: [setup, environment, tooling]
updated: 2026-07-02
---

# Getting Started — Recommended Environment

This vault is your **Deen OS**. It works on its own, but the full workflow assumes a few companion tools. Install these to get the same setup the workflow was designed around. Each is a separate, free, open project — links and exact steps below.

## 1. Obsidian — view and navigate this vault

The vault is plain markdown, so any editor works, but Obsidian turns it into a navigable knowledge base (backlinks, graph view, database tables).

- **Download:** https://obsidian.md/download
- **Open this vault:** Obsidian → *Open folder as vault* → select this folder.
- **Recommended plugin — TaskNotes** (task management): Settings → Community plugins → Browse → search *TaskNotes* → Install → Enable.
- **Bases** (database/table views over your notes) is built into Obsidian — no plugin needed.
- The `CLAUDE.md` file in each folder is a routing index that tells Claude where information belongs. You don't edit these by hand; leave them in place.

## 2. The Deen plugin — `/deen:setup` + `/deen:handoff` (this)

Already installed if you're reading this. To (re)install or update:

```
/plugin marketplace add andrydeen/deen-system
/plugin install deen@deen-system
```

- **`/deen:setup`** — builds and personalizes this vault (you already ran it).
- **`/deen:handoff`** — at the end of a work session, saves a compact note; at the start of the next, restores context. Invoke it explicitly by typing `/deen:handoff`.

## 3. Superpowers — disciplined Claude Code workflows

By Jesse Vincent. Gives Claude proven skills: brainstorming → spec → plan → build, test-driven development, systematic debugging, and code review. This is what makes Claude *think before coding*.

- **Source:** https://github.com/obra/superpowers
- **Install:**
  ```
  /plugin marketplace add anthropics/claude-plugins-official
  /plugin install superpowers@claude-plugins-official
  ```
- After install you don't call it directly — Claude invokes the right skill automatically (e.g. brainstorming before a feature, TDD while coding).

## 4. gstack — browser QA, dogfooding, and ship workflows

By Garry Tan. Adds a fast headless browser and a set of review/ship skills (`/browse`, `/review`, `/ship`, `/office-hours`, `/design-review`, and more).

- **Source:** https://github.com/garrytan/gstack
- **Requirements:** Git, [Bun](https://bun.sh) v1.0+, Node.js (Windows only).
- **Install** (paste into Claude Code):
  ```
  git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup
  ```
- After install: `/browse` for web browsing, `/review` on a branch with changes, `/office-hours` to think through what you're building.

## How they fit together

- **Deen plugin** = your personal context (this vault) + session continuity (handoff).
- **Superpowers** = *how* Claude approaches the work (think first, test, review).
- **gstack** = hands-on QA, review, and shipping for real apps and websites.
- **Obsidian** = where you read and connect everything.

A typical rhythm: open your project, let Superpowers drive the build discipline, reach for gstack when you need to drive a browser or ship, and finish the session with `/deen:handoff` so tomorrow starts where today ended.
