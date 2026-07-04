---
name: verify
description: Check that the Deen system is fully working on this machine — four areas (Claude Code practices, memory, handoff, Obsidian) reported green or red with an exact remedial step for every red. Invoke ONLY via the /deen:verify command or a Deen-qualified phrase such as "deen verify" or "deen check my setup". Do NOT auto-trigger on generic phrases like "verify" or "check setup" on their own. Read-only against the vault; re-runnable anytime. Reads the vault path from ~/.deen-system/config.md.
---

# Deen Verify

Checks the four areas of the Deen system on this machine and reports each **by name**. Read-only: it never writes to the vault. Re-run it as often as you like — after setup, after fixing a red area, after a plugin update.

## Step 0: Config

Read `~/.deen-system/config.md`. If it is missing → outcome **not-set-up**: tell the user to run `/deen:setup` first, and stop. Otherwise take `vault_path` from the frontmatter (it is already absolute).

Also read the installed plugin version from `${CLAUDE_PLUGIN_ROOT}/../.claude-plugin/plugin.json` if resolvable, else from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` — used by check 1.

## The four checks (fixed order; report each by name)

### 1. Claude Code practices

- `<vault_path>/Resources/guide-claude-code.md` exists, and all four `Resources/guide-*.md` files exist (`guide-claude-code`, `guide-memory`, `guide-handoff`, `guide-obsidian`).
- Each guide's `plugin_version` frontmatter stamp equals the installed plugin version. A lower stamp = stale.
- Ask the user to confirm they have read the practices guide (a practice has no tool-check; guide-read is the honest observable).

**Red remedial steps:** guide missing or stale → "re-run `/deen:setup` — the add-only re-run writes/refreshes the guides"; not read → "read `Resources/guide-claude-code.md` (≤10 min), then re-run `/deen:verify`".

### 2. Memory

- The three layers exist: the vault's `Context/` (with at least `me.md`), the vault's `wiki/` or `raw/` (project layer evidence may be empty before the first handoff — the directories or the guide's rule suffice), and the memory guide's **what goes where** table (`Resources/guide-memory.md`).
- Walk the user through storing **one real fact**: ask for a durable fact, have them name the layer the guide's table assigns, and confirm the fact landed there (e.g. a line added to a `Context/` file, or "remember this" for auto-memory).

**Red remedial steps:** a layer missing → "re-run `/deen:setup`"; the user can't place the fact → "open `Resources/guide-memory.md` and use the table — one fact, one home".

### 3. Handoff (the round-trip)

- `<vault_path>/log.md` contains at least one `restored:` line.
- At least one raw note exists under `<vault_path>/raw/<Project>/` whose date is **on or before** the timestamp of a `restored:` entry for the same project — a save that a later, genuinely new session restored.

**Red remedial step:** "work a session, run `/deen:handoff` to save, END the session, start a fresh session, run `/deen:handoff` to restore, then re-run `/deen:verify`. A save-and-read-back inside one session does not count."

### 4. Obsidian

- The directory `<vault_path>/.obsidian/` exists (Obsidian creates it when the vault folder is opened as a vault).
- Ask the user to confirm the vault opens in Obsidian.

**Red remedial step:** "install Obsidian (https://obsidian.md), then *Open folder as vault* → `<vault_path>` — see `Resources/guide-obsidian.md`."

## Outcomes

- **verified** — all four green: report the four areas by name, each with a ✓ and one line of what was checked. Congratulate: the setup is complete.
- **area-red** — any check failed: report every area by name (✓ or ✗), and for each ✗ give the exact remedial step above. End with: "fix the red area(s), then re-run `/deen:verify`."
- **not-set-up** — no config: point to `/deen:setup`.

Never mark an area green on hope: if a file check cannot be performed, the area is red with the remedial step.
