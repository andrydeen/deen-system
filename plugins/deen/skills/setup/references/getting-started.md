---
type: reference
tags: [setup, environment, tooling]
updated: 2026-07-02
---

# Getting Started — Recommended Environment

This vault is your **Deen OS**. It works on its own, but the full workflow assumes a handful of free, open companion tools. `/deen:setup` will offer to **install most of these for you** — the ones it can't (like the Obsidian app) it will hand you the exact steps for. This page is your reference either way.

Legend: 🤖 = `/deen:setup` can install it for you · 🙋 = you install it yourself.

## 1. Obsidian — view and navigate this vault 🙋

Plain markdown works in any editor, but Obsidian turns this vault into a navigable knowledge base (backlinks, graph, database tables).

- **Download:** https://obsidian.md (then *Open folder as vault* → select this folder)
- **Recommended plugin — TaskNotes:** Settings → Community plugins → Browse → *TaskNotes* → Install → Enable.
- **Bases** (database/table views) is built into Obsidian — no plugin needed.
- The `CLAUDE.md` in each folder is a routing index for Claude — leave those in place.

## 2. The Deen plugin — `/deen:setup` + `/deen:handoff` (this)

Already installed if you're reading this. Reinstall/update:
```
/plugin marketplace add andrydeen/deen-system
/plugin install deen@deen-system
```

## 3. Superpowers — disciplined Claude Code workflows 🤖

By Jesse Vincent. Brainstorm → spec → plan → build, TDD, systematic debugging, code review. Makes Claude *think before coding*.

- **Source:** https://github.com/obra/superpowers
- **Install:** `claude plugin marketplace add anthropics/claude-plugins-official` then `claude plugin install superpowers@claude-plugins-official`

## 4. GSD (get-shit-done) — phased planning & execution 🤖

Structured planning framework (`/gsd:new-project`, `/gsd:plan-phase`, `/gsd:execute-phase`, roadmaps, phases). Great for turning an idea into a plan you can execute step by step.

- **Package:** https://www.npmjs.com/package/@get-shit-done/cli
- **Install** (needs Node/npm): `npx @get-shit-done/cli@latest install` (follow its prompts)

## 4b. SDD — spec-driven development for live products 🤖

Per-feature engineering pipeline for products that already exist: `/sdd:specify` → `/sdd:clarify` → `/sdd:design` → `/sdd:tasks` → `/sdd:implement` → `/sdd:review` → `/sdd:ship`. Where GSD gets a project *to* version 1, SDD evolves it *after* version 1 — one feature at a time, with a written spec, architecture doc, and test-first implementation for each.

- **Source:** https://github.com/genkovich/sdd
- **Install:** `claude plugin marketplace add genkovich/sdd` then `claude plugin install sdd@sdd`

## 5. Context7 — up-to-date library docs during development 🤖

By Upstash. Pulls the *latest* documentation/specs for libraries, frameworks, and APIs into Claude, so you build against current versions instead of stale training data. Important for real development.

- **Install:** `claude plugin marketplace add anthropics/claude-plugins-official` then `claude plugin install context7@claude-plugins-official`

## 6. Playwright MCP — drive a real browser to check functionality 🤖

By Microsoft. Lets Claude open and control a browser to verify that what you built actually works (click through flows, check pages).

- **Source:** https://github.com/microsoft/playwright-mcp
- **Install:** `claude mcp add -s user playwright -- npx @playwright/mcp@latest`

## 7. gstack — browser QA, review, and ship workflows 🤖

By Garry Tan. Fast headless browser plus review/ship skills (`/browse`, `/review`, `/ship`, `/office-hours`, `/design-review`).

- **Source:** https://github.com/garrytan/gstack
- **Needs:** Git, [Bun](https://bun.sh) v1.0+ (Node.js on Windows).
- **Install:** `git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup`

## How they fit together

- **Deen** = your context (this vault) + session continuity (handoff).
- **Superpowers** = *how* Claude approaches the work (think first, test, review).
- **GSD** = break a project into phases and execute them — the road to version 1.
- **SDD** = after version 1 is live, build each new feature spec-first.
- **Context7** = build against the latest library specs, not stale docs.
- **Playwright MCP** = check in a real browser that it actually works.
- **gstack** = deeper browser QA, review, and shipping.
- **Obsidian** = where you read and connect everything.

> Newly installed plugins and MCP servers take effect after you restart Claude Code.
