# guardrails

Two things, nothing else:

1. **Passive safety hooks — active everywhere, zero tokens.** Installed with the plugin, no per-project setup:
   - `scan-secrets` — blocks edits that introduce API keys, tokens, passwords
   - `protect-files` — blocks edits to `.env`, key files, lockfiles, generated files, `.git/`; asks before `settings.json` changes
   - `block-dangerous-commands` — blocks force-push, `rm -rf` on dangerous targets, `DROP TABLE`, `DELETE` without `WHERE`, `curl | sh`, `dd`/`mkfs` on devices, `git reset --hard`, accidental `npm publish`
   - `warn-large-files` — blocks writes into `node_modules/`, `dist/`, `.next/`, other generated dirs
2. **`/guardrails:rules`** — scans the current project and generates path-scoped `.claude/rules/*.md` (testing, error handling, database, frontend, security conventions distilled from the actual code). Run it once per mature project; re-runs gap-analyze instead of clobbering.

## Install

```
/plugin marketplace add andrydeen/deen-system
/plugin install guardrails@deen-system
```

Hooks are live after a Claude Code restart. Run `/guardrails:rules` inside any project with settled conventions.

## What was deliberately left out

This plugin is derived from [poshan0126/dotclaude](https://github.com/poshan0126/dotclaude) (MIT — thank you). The workflow skills (tdd, ship, pr-review, debug-fix, …) and review agents from the original are **intentionally not included**: in the Deen stack those jobs belong to Superpowers, GSD, SDD, and GStack. One local modification: the push-to-protected-branch blocks are removed (this stack works trunk-based); force-push remains blocked.
