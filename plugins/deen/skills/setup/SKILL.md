---
name: setup
description: Bootstrap a personal Deen OS context vault and personalize it through guided onboarding. Creates the directory structure, routing CLAUDE.md files, and Context scaffolds, writes a per-user config at ~/.deen-system/config.md, then interviews the user to fill in identity, business, brand, customers, and strategy. Runs natively in Claude Code (conversational, English). Use when the user says "set up", "bootstrap", "initialize", "onboarding", or runs /deen:setup.
---

# Deen OS — Setup + Onboarding

USE WHEN the user runs `/deen:setup` or asks to set up their vault, bootstrap the assistant, or initialize the Deen system.

Two phases:
- **Phase A**: Bootstrap — ask where the vault goes, write config, create the structure and system files.
- **Phase B**: Onboarding — interview the user and personalize the Context files.

## Resolving reference file paths

Every `references/<file>.md` below lives in the `references/` directory next to THIS `SKILL.md`. When the `CLAUDE_PLUGIN_ROOT` environment variable is set, references live at `${CLAUDE_PLUGIN_ROOT}/skills/setup/references/` — use that path first. Otherwise, read them relative to this SKILL.md. As a last-resort fallback only, discover the directory using:

```bash
find / -type d -path '*deen/skills/setup/references' 2>/dev/null | head -1
```

Write paths (e.g. `<vault>/Context/me.md`) resolve under the vault path chosen in Phase A.

## Phase A: Bootstrap

### Step A.1: Choose vault path and name, write config

Ask the user two short questions (plain chat or one `AskUserQuestion`):
1. Their name (for the config and `Context/me.md`).
2. Where to create the vault. Default `~/Deen-OS`. Expand `~` to `$HOME`.

Then write `~/.deen-system/config.md` (create `~/.deen-system/` if needed):

```markdown
---
name: <their name>
vault_path: <absolute path, e.g. /Users/you/Deen-OS>  # store the expanded absolute path, not a literal ~
handoff_enabled: true
---
```

### Step A.2: Pre-flight

If `<vault_path>/CLAUDE.md` already exists, the vault is set up. Default to an **add-only update**: detect what already exists, skip completed areas, and add only what's missing (e.g. the four `Resources/guide-*.md` files on a vault created by an older plugin version). Refresh a guide copy only when its `plugin_version` stamp is older than the installed plugin version — guide copies are plugin-owned; **never modify or delete any other existing vault content**. Also offer: restart interview (keep structure, refresh files), full reset (delete and rebuild — confirm twice), or cancel. Otherwise (no vault) continue.

**Missing prerequisite rule (any step).** If a step needs something that isn't there (e.g. the Obsidian app for the knowledge layer, or `git` for an install), do not stall and do not start over: name the **missing prerequisite**, give the exact remedial step (install command or link), and tell the user to re-run `/deen:setup` after fixing it — the add-only re-run will skip everything already done and continue from the incomplete step.

### Step A.3: Create the directory structure

```bash
V="<vault_path>"
mkdir -p "$V/.claude" "$V/Context" "$V/Projects" "$V/Daily" "$V/Resources" "$V/Skills" \
  "$V/Intelligence/meetings/team-standups" "$V/Intelligence/meetings/client-calls" \
  "$V/Intelligence/meetings/one-on-ones" "$V/Intelligence/meetings/general" \
  "$V/Intelligence/competitors" "$V/Intelligence/market" "$V/Intelligence/decisions" \
  "$V/Intelligence/archive"
```

### Step A.4: Write system files from references

Read each reference file and write its content verbatim to the vault path:

| Reference | Write to |
|---|---|
| `references/settings-json-template.md` | `<vault>/.claude/settings.json` |
| `references/claudeignore-template.md` | `<vault>/.claudeignore` |
| `references/gitignore-template.md` | `<vault>/.gitignore` |
| `references/claude-md-template.md` | `<vault>/CLAUDE.md` |
| `references/claude-md-context.md` | `<vault>/Context/CLAUDE.md` |
| `references/claude-md-projects.md` | `<vault>/Projects/CLAUDE.md` |
| `references/claude-md-daily.md` | `<vault>/Daily/CLAUDE.md` |
| `references/claude-md-intelligence.md` | `<vault>/Intelligence/CLAUDE.md` |
| `references/claude-md-resources.md` | `<vault>/Resources/CLAUDE.md` |
| `references/claude-md-skills.md` | `<vault>/Skills/CLAUDE.md` |
| `references/getting-started.md` | `<vault>/Resources/getting-started.md` |
| `references/guide-claude-code.md` | `<vault>/Resources/guide-claude-code.md` |
| `references/guide-memory.md` | `<vault>/Resources/guide-memory.md` |
| `references/guide-handoff.md` | `<vault>/Resources/guide-handoff.md` |
| `references/guide-obsidian.md` | `<vault>/Resources/guide-obsidian.md` |

**Version-stamp the four guide copies.** When writing each `guide-*.md` into the vault, add one frontmatter line to the copy: `plugin_version: <version>` — read `<version>` from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`. The bundled reference has no stamp; only vault copies do. The stamp is how re-runs and `/deen:verify` detect stale guides.

### Step A.5: Create the starter Context file

Read `references/context-me.md` and write it to `<vault>/Context/me.md`. That is the only Context file created now. The rest are created in Phase B Build, only when the answers contain data for them.

### Step A.6: Confirm bootstrap

Tell the user the structure was created, list the main folders (`Context`, `Projects`, `Daily`, `Resources`, `Skills`, `Intelligence`), note the vault path, mention Obsidian is optional for viewing, and that `/deen:handoff` will use this vault. Also point them to **`Resources/getting-started.md`** — it explains the recommended companion tools (Obsidian, the Superpowers plugin, and gstack) with install links and how they fit together, so they can set up the full workflow, not just the vault — and to the four area guides now in `Resources/` (`guide-claude-code`, `guide-memory`, `guide-handoff`, `guide-obsidian`): short "when and why" reads for how this system is used day to day. Mention that once they've worked a first session and done a handoff save + restore, **`/deen:verify`** will check all four areas and confirm the setup is complete. Then start Phase B.

## Phase B: Onboarding — Guided Brain Dump (conversational)

Run natively in chat. No forms, no widgets. Send one orienting message, then walk through 12 categories in 3 rounds of 4. For each round, present the 4 categories with their bullets and invite the user to brain-dump: type free text, paste a dictation transcript, paste links (you will fetch them with WebFetch), or give file paths (you will Read them). Blank = skip that category. The bullets are inspiration, not a form.

Orienting message (send verbatim, no tool call):

> Twelve categories, in three rounds of four. This isn't a questionnaire, it's a guided brain dump. For each category, dump whatever comes to mind around the bullets, paste a dictation transcript, drop links, or point me at files. Skip anything that doesn't apply. The more you give, the less templated your vault is from the start. Reply "skip all" any time to jump to defaults.

**Round 1 — You and the business (Q1–Q4)**

**Q1. You** — name, role/title, location, niche; when you do your best work; how you'd want a respected peer to introduce you; 5 qualities that describe you.

**Q2. Origin and POV** — why you do this; a belief you hold even when unpopular; the big idea/wedge your work is built on; who or what you're fighting.

**Q3. What you sell** (one paragraph per revenue line, skip if none) — name, what it does, who it's for, stage; current revenue baseline; how it came about.

**Q4. The promise** — 1–3 problems you solve; for each, are clients already aware or must you teach them; your value prop in one sentence; the promise/guarantee you make; why clients actually choose you.

**Round 2 — Customer and brand (Q5–Q8)**

**Q5. The customer** — title/role/niche; their day and tools; the words they use for their problem; their dream outcome; the situation/trigger before they buy; decision time; media they follow; 3–5 real examples.

**Q6. Voice and visual** — tone descriptors; 5 qualities of how you sound; signature phrases; words you'd never use; topics you love; topics you avoid publicly; brand colors/fonts/taglines; the feeling to leave people with. Or paste a sample and I'll extract.

**Q7. Positioning** — the enemy you're fighting; how you solve it differently than the obvious alternatives; 3–4 clear messages to associate with your name/brand.

**Q8. This year's priorities** — 1–3 outcomes with a number; the why behind each; what you're deliberately saying no to.

**Round 3 — How you operate (Q9–Q12)**

**Q9. Active projects** (per project) — name, one-line goal, status, deadline; which business it belongs to; who else is involved.

**Q10. People you work with** — team, contractors, key external contacts; for each name, role, how you work together. Skip if solo.

**Q11. Your stack** — tools across comms, meetings, CRM, content, finance, dev, automation; the source of truth for each main workflow.

**Q12. What drains you / to automate** — top 1–2 painful recurring processes (When X happens → I do Y → it takes Z → result W → but I want V); what's eating your attention right now.

After each round, ingest what the user gave: store brain-dump text raw (don't paraphrase), fetch every link with WebFetch, Read every file/folder path. Merge into one corpus tagged by category. No commentary between rounds — go straight to the next round.

## Phase B+: Additional context drop

Before building, ask once (`AskUserQuestion`, header `Context`): is there anything else to pull from — files (PDF/MD/DOCX), links (LinkedIn, sites, Notion, Google Docs), a local folder, or raw text? Options: paste links/files · point to a folder · build from answers · skip. For any "yes", fetch links (WebFetch), Read files (use `pages` for large PDFs; `pandoc`/`textutil` for docx/pptx/xlsx if available), Glob folders. Merge into the corpus. One-sentence summary of what you pulled, then build.

## Phase B Build: Personalize the vault

Work silently. For each Context file: read its `references/` scaffold to learn the section structure, then replace every `[bracketed placeholder]` with real data from the answers + corpus. If a section has no data, omit the whole section — never leave placeholders. Keep the user's exact names, numbers, URLs, and phrasing. Set frontmatter `updated:` to today.

Create (only when there is data):
- `Context/me.md` — always (Q1 + Q2 + Q12 + corpus).
- `Context/business.md` — if Q3 had content.
- `Context/services.md` — if multiple revenue lines / product docs.
- `Context/pain-points.md` — if Q4/Q2 named problems (include the aware-vs-teach signal).
- `Context/icp.md` — if Q5 had content.
- `Context/brand.md` — if Q6/Q7/Q4 had content (voice, positioning, value prop).
- `Context/strategy.md` — if Q8 had content.
- `Context/team.md` — if Q10 had content.
- `Context/infrastructure.md` — if Q11/Q12 had content.

Projects: from Q9 + corpus. Simple mention → just `Projects/<name>/README.md`. More detail → add `research/`, `specs/`, `drafts/`, `notes/` files as the content warrants. Don't cram everything into the README; don't create empty subdirs.

First daily note: `Daily/<today>.md` with `type: daily-note`, today's date, and a short session block (Focus: initial setup; Completed: bootstrap + onboarding; Next Steps: based on what was discussed).

## Confirm completion

Summarize which Context files and how many projects were created, note the vault path, say they can add more context anytime, and suggest a next action based on what they shared.

## Phase C: Offer to set up the recommended environment

After the vault is built, offer to install the companion tools that make the full workflow work (detailed in `Resources/getting-started.md`). Be warm and concrete — this is a favor, not a checklist. Briefly list what each tool is for:

- **Superpowers** — disciplined workflows (plan, TDD, debug, review)
- **GSD** — phased planning & execution (getting a project to version 1)
- **SDD** — spec-driven development: per-feature pipeline for products that are already live (spec → design → tasks → implement → review → ship)
- **Context7** — up-to-date library docs while you build
- **Playwright MCP** — drive a real browser to check functionality
- **gstack** — browser QA / review / ship
- **Obsidian** — the app to read this vault (you install this one yourself)

Then ask with one `AskUserQuestion` (header `Environment`):
- Question: "Want me to set these up for you now? I can install most of them for you; anything I can't (like the Obsidian app) I'll give you the exact steps for."
- Options: `Yes — install what you can` · `Let me pick which ones` · `No — I'll do it myself`

**If they say yes** (or choose a subset), install what the environment allows. Check prerequisites first, run each, and report per-tool success or failure. Never fail the whole setup because one install failed — report it and continue.

```bash
# Claude Code plugins (Superpowers + Context7): add the official marketplace once (idempotent), then install
claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true
claude plugin install superpowers@claude-plugins-official
claude plugin install context7@claude-plugins-official

# SDD — spec-driven development pipeline (per-feature work on live products)
claude plugin marketplace add genkovich/sdd 2>/dev/null || true
claude plugin install sdd@sdd

# Playwright MCP (browser checks), user scope so every project gets it
claude mcp add -s user playwright -- npx @playwright/mcp@latest

# GSD planning framework — needs Node/npm
command -v npx >/dev/null && npx @get-shit-done/cli@latest install || echo "Install Node.js (https://nodejs.org) first, then run: npx @get-shit-done/cli@latest install"

# gstack — needs git + Bun v1.0+
if command -v bun >/dev/null; then
  git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && (cd ~/.claude/skills/gstack && ./setup)
else
  echo "Install Bun (https://bun.sh) first, then clone gstack (see Resources/getting-started.md)."
fi
```

**Always ask the user to do themselves** (cannot be installed from here):
- **Obsidian** — download from https://obsidian.md and open the vault folder as a vault (Bases is built in; add the TaskNotes community plugin).

**After installing:** give a short, friendly summary — what got installed, what needs a **Claude Code restart** to take effect (plugins + MCP servers do), and the one or two things they must finish themselves (Obsidian, plus anything a missing prerequisite blocked). Point them to `Resources/getting-started.md` for the full reference. **If they said no**, just point them to that file and wrap up warmly.

## Guidelines

- One universal structure, no mode selection.
- Templates are scaffolds, not outputs. Never leave bracketed placeholders in a finished file.
- Accept any format: typed text, transcripts, pasted docs, links, folder paths, or skips.
- Don't narrate each file. Build silently, summarize at the end.
