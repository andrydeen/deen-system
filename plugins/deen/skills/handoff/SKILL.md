---
name: handoff
description: Save a compact session handoff note to your Deen OS vault and restore context at the start of the next session. Trigger on "handoff", "end of session", "wrap up", "save my progress", "session note"; and on "restore context", "what did we do last time", or starting a session with no clear task. Uses ~/.deen-system/config.md for the vault path.
---

# Deen Handoff

## Config

Read `vault_path` from `~/.deen-system/config.md` (frontmatter). The `vault_path` is already an absolute path (setup expanded any leading `~`), so use it directly in shell commands. If that file is missing, tell the user to run `/deen:setup` first, then continue with `vault_path` = `$HOME/Deen-OS`.

If `handoff_enabled` is `false` in the config, do nothing and stop silently.

Detect the project name:

```bash
basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

Use the project name as-is for all vault paths (`raw/<Project>/`, `wiki/<Project>/`).

Vault layout:
```
<vault_path>/
├── raw/<Project>/YYYY-MM-DD.md   ← raw session note (immutable once written)
├── wiki/<Project>/overview.md    ← current project state (rewritten each session)
├── wiki/<Project>/patterns.md    ← accumulated patterns (append-only)
├── log.md                         ← append-only session log
└── index.md                       ← project catalog
```

## Mode A — End of session

### Step 1: Gather facts

```bash
basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
git log --oneline -3 2>/dev/null
git diff HEAD~1..HEAD --name-only 2>/dev/null
git status --short 2>/dev/null
date +%Y-%m-%d
```
If git commands return nothing (no repo), skip the git-derived bullets. Also draw on the conversation for what was built, patterns found, decisions made, and what's next.

### Step 2: Write the raw note

Compact, under 400 tokens, concrete outcomes only. Write to `<vault_path>/raw/<Project>/<YYYY-MM-DD>.md` (create the directory if needed):

```markdown
## Handoff — <Project> — <YYYY-MM-DD>

### What we built
- <bullet per change, include file path>

### Key patterns (copy-paste ready)
<only NEW patterns from this session>

### Decisions
- <decision>: <one-line reason>

### Files changed
- `path/to/file` — description

### Next session
- <specific next task>
```
Omit any empty section.

### Step 3: Update the wiki

- `<vault_path>/wiki/<Project>/overview.md` — rewrite fully to current state: what's done (a short table), what's in progress, what's next, key patterns (brief). Create the directory if needed.
- `<vault_path>/wiki/<Project>/patterns.md` — append only NEW patterns/decisions under the relevant heading with a date stamp. Don't rewrite existing entries.
- `<vault_path>/log.md` — append one line: `## <YYYY-MM-DD> <Project> | <one-line summary>`.
- `<vault_path>/index.md` — update this project's row (last session date + status). Create the file with a header row if it doesn't exist.

### Step 4: Update ARCHITECTURE.md (only if architectural)

Architectural = a new service/integration, a new/removed endpoint or tool, a completed major block, a schema change, a decision that changes how components connect. NOT architectural = bug fixes, config tweaks, docs/tests only.

If architectural: read `ARCHITECTURE.md` in the project root, rewrite the affected sections in place to reflect current reality (do not append), update its "Last updated" date and any "Built vs. Not Yet Built" checklist. Note in the confirmation that it was updated. If not architectural, skip silently.

### Step 5: Confirm

Tell the user: `Saved to <vault_path>/raw/<Project>/<date>.md — wiki updated.` Do not print the full note.

## Mode B — Start of session

### Step 1: Read the overview

```bash
cat "<vault_path>/wiki/<Project>/overview.md"
```

### Step 2: Confirm in 2–3 sentences

State the project, current state, and what's next. Don't repeat the full file. Then ask: "What would you like to work on?"
