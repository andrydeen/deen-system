---
name: rules
description: Generate path-scoped .claude/rules/*.md for the current project by scanning its codebase — evidence-based, minimal, nothing installed without justification. Use when the user asks to "generate rules", "set up coding rules", "run guardrails rules", "/guardrails:rules", or wants project conventions (testing, error handling, database, frontend, security) distilled into rules Claude loads automatically when editing matching files. Best run on a live/mature project where conventions have settled. Re-runs do a gap analysis, never clobber.
argument-hint: "[optional focus area, e.g. 'frontend' or 'backend']"
disable-model-invocation: true
---

Generate **path-scoped rules** for this project: `.claude/rules/*.md` files whose frontmatter `paths:` globs make Claude load each rule only when editing matching files. One governing principle, inherited from dotclaude: **write nothing without evidence.** Every rule file must be justified by something actually found in the codebase. When in doubt, leave it out.

**Scope boundaries (hard):** this skill writes ONLY `.claude/rules/*.md`. It never touches `CLAUDE.md`, `ARCHITECTURE.md`, `.claude/settings.json`, `.planning/`, `docs/features/`, hooks, agents, or skills. The safety hooks ship with the guardrails plugin itself and are already active — do not install per-project copies.

## Phase 1: Scan (read-only)

Build a small evidence table. Read real code, not just manifests:

1. **Stack + commands**: manifests (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, …) and CI workflows. Record the *actual* test/lint/build commands.
2. **Source layout**: the real source directories. These become `paths:` globs — record actual paths, never assume `src/`.
3. **Tests**: config + **open 2–3 real test files**: runner, naming convention, directory layout, assertion style, how much mocking they actually use.
4. **Backend/API**: route/handler/service dirs; ORM + migration dirs (`prisma/`, `supabase/migrations/`, `alembic/`, …).
5. **Frontend**: component dirs, framework, styling approach.
6. **Conventions**: read 5–10 representative source files — naming style, error-handling patterns (typed errors vs bare catch), comment density, generated-file markers.
7. **Existing rules**: current `.claude/rules/`, `CLAUDE.md`, `.cursorrules` — content to respect and cross-reference, never to duplicate or clobber.

If `$ARGUMENTS` names a focus area, weight the scan toward it. If the project has no source code yet, say so and stop — rules distilled from nothing are noise.

## Phase 2: Confirm (one AskUserQuestion round)

Present a compact findings summary (stack, test runner, layout, conventions observed, which rule files the evidence justifies). Then ask:
- "Did I read the project right?" — correct / mostly (correct via Other) / wrong.
- "Which rule files should I write?" — multiSelect of ONLY the justified ones, preselected per evidence.

Justification mapping (no exceptions without user override):

| Rule file | Write only if |
|---|---|
| `code-quality.md` | Always justified (universal) |
| `testing.md` | A test suite actually exists |
| `error-handling.md` | Backend/API surfaces exist |
| `security.md` | Backend/API surfaces or auth code exist |
| `database.md` | Migrations or ORM detected |
| `frontend.md` | Frontend component files exist |

## Phase 3: Write the rules

For each selected rule file, start from the matching template in [references/](references/) and **customize it to the evidence** — replace generic advice with this project's actual conventions, commands, and directory names. Delete template lines that don't apply. Add project-specific lines the scan surfaced (e.g. "all Supabase access goes through `lib/db/`, never raw clients in routes").

Prepend frontmatter with real path globs from Phase 1 (omit `paths:` only for `code-quality.md`, which applies everywhere):

```markdown
---
paths:
  - "app/**/*.ts"
  - "lib/**/*.ts"
---
```

Keep each file under ~30 lines. Rules are context loaded on every matching edit — every line costs tokens forever. A rule that restates what any senior engineer does by default is noise; keep only what is *specific to this project* or *repeatedly violated by default behavior*.

## Phase 4: Re-runs = gap analysis

If `.claude/rules/` already has files: diff reality against them. Propose additions for new evidence, flag rules whose `paths:` no longer match anything (stale), and show every change before applying. Never rewrite a user-customized rule without showing the diff first.

## Confirm

List the files written with their `paths:` scope, one line each. Remind: rules load automatically when Claude edits matching files — no further wiring needed.
