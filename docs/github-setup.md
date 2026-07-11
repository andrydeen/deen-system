# GitHub setup: the `gh` CLI

GitHub integration is load-bearing for the whole workflow: Claude Code uses the **`gh`** CLI to open pull requests, file and read issues, create repos, and call the GitHub API — without it, your agent can code but can't ship. Set it up once per machine, before your first project.

## 1. Install

**macOS:**
```bash
brew install gh
```

**Windows:**
```powershell
winget install --id GitHub.cli
```

**Linux:** see [github.com/cli/cli#installation](https://github.com/cli/cli#installation).

## 2. Authenticate (one time)

```bash
gh auth login
```

Pick: **GitHub.com** → **HTTPS** → **Login with a web browser**, and follow the device-code flow. This also configures git itself to push/pull over HTTPS without passwords (`gh` acts as the credential helper — no SSH keys needed).

Verify:

```bash
gh auth status
```

Expected: `✓ Logged in to github.com as <you>`.

## 3. What this unlocks in the workflow

- **New project → private repo in one line** (the walkthrough's bootstrap step):
  ```bash
  git init && git add -A && git commit -m "init"
  gh repo create my-project --private --source=. --push
  ```
- **Pull requests from the agent**: review/ship skills end with `gh pr create`; you read the PR on GitHub and merge there.
- **Issues as your bug backlog**: during support triage (see [post-release-support.md](post-release-support.md)), bugs not worth fixing immediately are filed with `gh issue create` — with the replay link and the red-lamp repro command in the body — instead of dying in a chat scroll.
- **API access for automations**: `gh api ...` lets sessions and scripts read/write repo contents without extra tokens.

## 4. Private repos as free backup for your vaults

Your Deen OS vault and handoff notes are plain markdown — version them:

```bash
cd ~/Deen-OS   # or wherever /deen:setup put your vault
git init && git add -A && git commit -m "vault: initial"
gh repo create deen-os-vault --private --source=. --push
```

From then on, a periodic `git add -A && git commit -m "vault sync" && git push` (yourself, or as part of a weekly review) gives you full history and an off-machine backup. Keep vault repos **private** — they contain your business context.

## 5. Rules of thumb

- One `gh auth login` per machine — tokens are stored in the OS keychain.
- Default new repos to `--private`; make things public as a deliberate decision, never as a default.
- If an agent session says it can't push or create a PR, the first check is always `gh auth status`.
