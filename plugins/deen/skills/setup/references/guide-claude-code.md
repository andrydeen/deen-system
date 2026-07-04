---
type: reference
tags: [claude-code, practices, workflow]
updated: 2026-07-04
---

> **Plugin-owned guide.** Written by `/deen:setup`; **refreshed** (overwritten) when you re-run setup after a plugin update. Keep personal notes elsewhere.

# Claude Code — how we work

These are practices, not button locations — they survive tool updates. Five habits make the difference between "a chatbot that edits files" and a working system.

## 1. Start sessions with context, not questions

Don't open with "what should we do?" — restore first. `/deen:handoff` reads your project's overview back; a per-project `CLAUDE.md` (and `ARCHITECTURE.md`, if the project has one) tells Claude how the codebase works. Thirty seconds of context beats twenty minutes of re-explaining.

## 2. Say what done looks like

The single highest-leverage prompting habit: give a verifiable goal, not an activity. "Add validation" → "reject empty names and emails without @, with a test proving both". When Claude knows the finish line, it can loop toward it on its own instead of asking you at every step.

## 3. Let the system push back

Good working sessions are dialogues. If a request is ambiguous, expect (and welcome) a clarifying question before code gets written. If you have a plan, ask Claude to challenge it before executing it. Silent agreement is how bad designs ship.

## 4. Small, verified steps

Prefer a sequence of small changes — each tested, each committed — over one giant diff. Ask for the test first when the change is risky. If something breaks, the last green commit is your safety net. Review diffs before they're committed; you own what ships.

## 5. End sessions deliberately

A session that just… stops loses its learnings. End with `/deen:handoff`: decisions get recorded, next steps get written down, and tomorrow's session starts warm. If the session changed how a project is built, the handoff also updates that project's `ARCHITECTURE.md`.

## Where the rest of the system fits

- **Memory** (see the memory guide): preferences → auto-memory; who-you-are context → your vault's `Context/`.
- **Companion tools** (see `getting-started.md`): disciplined workflows, up-to-date library docs, browser verification — install what your work needs.
- **Obsidian** (see the Obsidian guide): where you read everything the system writes.

Adopt the five habits for one week and they become invisible — that's the point.
