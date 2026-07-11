# Deen System

Three Claude Code plugins: **`deen`** (context vault + session continuity), **`guardrails`** (safety hooks + rules generator — see [plugins/guardrails/README.md](plugins/guardrails/README.md)), and **`studio`** (web design & AI video toolkit — see [plugins/studio/README.md](plugins/studio/README.md); install with `/plugin install studio@deen-system`).

The `deen` plugin gives you three things:

- **`/deen:setup`** — bootstraps a personal "Deen OS" context vault (a structured set of markdown files about you, your business, brand, customers, and strategy), interviews you to fill it in, and installs four short area guides (Claude Code practices, memory, handoff, Obsidian) into your vault.
- **`/deen:handoff`** — saves a compact note at the end of a work session and restores context at the start of the next one, so any project can be picked back up cleanly.
- **`/deen:verify`** — checks all four setup areas on your machine (guides present and current, memory layers, a real two-session handoff round-trip, Obsidian vault) and names the exact remedial step for anything red.

Everything lives in plain markdown you own. Obsidian is optional (nice for viewing, not required).

## Install

```
/plugin marketplace add andrydeen/deen-system
/plugin install deen@deen-system
```

Then, in any project:

```
/deen:setup     # first time: build and personalize your vault
/deen:handoff   # end of a session: save state · start of a session: restore it
/deen:verify    # after setup: confirm all four areas actually work on your machine
```

## What `/deen:setup` creates

A vault (default `~/Deen-OS`) with:

- `Context/` — `me`, `business`, `services`, `brand`, `icp`, `pain-points`, `strategy`, `team`, `infrastructure`
- `Projects/`, `Daily/`, `Resources/`, `Skills/`, `Intelligence/`
- A routing `CLAUDE.md` in every folder so Claude always knows where information belongs

It also writes `~/.deen-system/config.md` (your name, vault path) that `/deen:handoff` reads.

## What `/deen:handoff` does

- **End of session:** writes `raw/<Project>/YYYY-MM-DD.md`, refreshes `wiki/<Project>/overview.md`, appends patterns/log, and updates `ARCHITECTURE.md` when the session changed the architecture.
- **Start of session:** reads the overview and summarizes where you left off.

## Recommended companion tooling

The plugin works on its own, but the full workflow assumes a handful of free, open companion tools. **`/deen:setup` offers to install most of these for you** (and asks you to install the rest, like the Obsidian app). It also writes a `Resources/getting-started.md` into your vault with the same guidance and exact steps.

- **[Obsidian](https://obsidian.md)** *(you install)* — open your vault folder as a vault to browse it as a linked knowledge base. Recommended plugin: **TaskNotes**; database views (**Bases**) are built in.
- **[Superpowers](https://github.com/obra/superpowers)** (Jesse Vincent) — disciplined workflows (brainstorm → spec → plan → build, TDD, debugging, review): `claude plugin install superpowers@claude-plugins-official`
- **[GSD / get-shit-done](https://www.npmjs.com/package/@get-shit-done/cli)** — phased planning & execution (`/gsd:*`), the road to version 1: `npx @get-shit-done/cli@latest install`
- **[SDD](https://github.com/genkovich/sdd)** — spec-driven development (`/sdd:*`): per-feature pipeline (spec → design → tasks → implement → review → ship) for products that are already live: `claude plugin marketplace add genkovich/sdd` then `claude plugin install sdd@sdd`
- **Guardrails** (this marketplace) — always-on safety hooks (secret scanning, protected files, dangerous-command blocking) + `/guardrails:rules` to generate per-project coding rules once a codebase matures: `claude plugin install guardrails@deen-system`
- **[Context7](https://github.com/upstash/context7)** (Upstash) — pulls the latest library/framework docs into Claude so you build against current specs: `claude plugin install context7@claude-plugins-official`
- **[Playwright MCP](https://github.com/microsoft/playwright-mcp)** (Microsoft) — drive a real browser to verify functionality: `claude mcp add -s user playwright -- npx @playwright/mcp@latest`
- **[gstack](https://github.com/garrytan/gstack)** (Garry Tan) — browser QA + review/ship skills. Needs Git + [Bun](https://bun.sh): `git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup`

How they fit: **Deen** = your context + session continuity · **Superpowers** = how Claude approaches the work · **GSD** = phased planning to version 1 · **SDD** = per-feature pipeline after launch · **Guardrails** = always-on safety net + rules for mature codebases · **Context7** = latest specs · **Playwright MCP** / **gstack** = check it in a real browser & ship · **Obsidian** = where you read it all.

**New here? Start with the walkthrough:** [docs/starting-a-new-project.md](docs/starting-a-new-project.md) — a step-by-step guide from "I have an idea" (or a spec document) to a live product, with the exact command to run at every stage.

**Before your first project:** [docs/github-setup.md](docs/github-setup.md) — install and authenticate the `gh` CLI so your agent can create repos, open PRs, and file issues.

**Building websites or AI video?** [docs/creative-stack.md](docs/creative-stack.md) — the `studio` plugin plus the third-party design/video skills that pair with it.

**After your product is live:** [docs/post-release-support.md](docs/post-release-support.md) — the post-release support system: session-replay bug reports (PostHog), uptime + error alerts, the three support tiers with AI-assisted triage, and the Red Lamp debugging rule.

## Requirements

- Claude Code. `git` is used when present (falls back gracefully). Nothing else is required to run the plugin itself; the tools above are recommended for the full workflow, and the [`gh` CLI](docs/github-setup.md) is strongly recommended so agents can ship (repos, PRs, issues).

## License

MIT
