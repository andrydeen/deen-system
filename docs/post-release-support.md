# Post-release support: bugs, alerts, and AI-assisted triage

What to build around a product *after* it goes live, so that bugs are observed instead of described, and support scales without hiring. This is the companion to [starting-a-new-project.md](starting-a-new-project.md) — that guide ends at "ship v1"; this one starts there.

> **The one rule:** a feature is not "shipped" until three things exist alongside it — **instrumentation** (you can see it break), **an alert path** (breaking reaches you in minutes, not when a customer emails), and **a playbook entry** (the known fix is written down). Build these in the same session as the feature, not after launch.

## The Red Lamp rule (how every bug gets fixed)

Never fix a bug straight away. The sequence is fixed:

1. **Build the red lamp first** — a minimal check that reproduces the bug and fails on exactly that problem. Any fast observable form counts: a failing test, a `curl` command, a small script, a Playwright scenario, a log query. Pick whatever shows "yes, the bug exists" quickest.
2. **State the exact command to run it** — so a human can see the lamp red themselves.
3. Only then investigate root cause and apply the fix.
4. **Prove the fix with the same lamp** — rerun the same command; red → green is the proof. A different check passing does not count.

If you can't make the bug fail reliably, say so — that's a finding to report, not a step to skip. Ask your AI assistant to follow this order explicitly: *"Don't fix yet. First build a minimal check that reproduces this bug and fails on it, tell me the command to run it, and only then propose the fix."*

## System 1 — Bug reports you can watch (PostHog)

Stop asking users to describe bugs; record what they experienced. [PostHog](https://posthog.com) (free tier: ~5k session replays + ~100k errors/month) covers session replay, error tracking, and rage-click detection in one tool. One PostHog project **per product**, each with its own key.

Tracking is a dial, not a switch — climb it one level at a time, per product:

| Level | What | When |
|---|---|---|
| 1 | Pageviews only (cookieless, autocapture off) | At launch — fastest safe drop-in |
| 2 | + Session replay, error capture, rage clicks, input masking on public forms | **Before alpha/beta testing starts** — testers hit the most bugs and describe them worst; the recorder must already be running |
| 3 | + Custom funnel events (viewed → submitted → confirmed) | When conversion questions appear |
| 4 | + Feature flags / experiments | Much later, if ever |

Practical notes: proxy PostHog through your own domain (a `/ingest` rewrite) so ad-blockers and strict CSPs don't eat events; mask input fields on public forms so customer PII never appears in recordings; link backend errors to the frontend replay via the PostHog session-id header. Internal tools with no real users stay at level 1 — don't record what nobody watches.

## System 2 — Alerts and the three support tiers

Route every failure signal to one place you actually look at (a messenger you already use), via any automation layer (n8n, Zapier, a cron script):

- **Uptime**: ping each live product every 5 minutes; on failure wait ~90s and re-check before alerting (kills false alarms); while down, re-alert at most every 30 minutes (kills spam).
- **Error spikes / rage clicks**: PostHog webhook → your automation → messenger.
- **In-app "Report a problem" button**: ~30 lines; auto-attach the session-replay link and URL so the user types one sentence and the recording does the rest.

Every alert should carry: product, error, replay link, and a suggested action — context packaged *for* a decision.

Build three tiers **before** you need them:

| Tier | What happens | Who acts |
|---|---|---|
| **T1 — Automated** | Known issue with a documented fix; automation runs the remediation and logs it. Grows toward 60–70% of volume over time | No human |
| **T2 — AI-assisted triage** | Unknown issue. You open a coding-agent session (e.g. Claude Code) with the alert context; the agent builds the red lamp, fixes, and **appends the case to the playbook** — so next time it's T1. Bugs not worth fixing now become GitHub Issues (with replay link + red lamp) — a durable backlog instead of messenger scroll | Agent + you decide |
| **T3 — Incident** | Multiple users affected, or security/data integrity involved. A pre-written incident playbook drives it: who's notified, what gets locked down, the customer-comms template | You, immediately |

The AI layer here is deliberately thin at first: the agent *assists* triage; it does not answer customers end-to-end. Full support automation only becomes safe after the playbook has accumulated real known issues — automate answers from evidence, not from guesses.

## System 3 — The playbook (the support brain that compounds)

Per live product: `docs/support/playbook.md` in the repo. One entry per failure mode, fixed shape:

```markdown
## <Flow> — <failure mode>          e.g. "Checkout — payment webhook missed"
**Symptoms:** what the user sees / what the alert says
**Red lamp:** exact command that reproduces/confirms it
**Diagnosis:** what to check, in order
**Fix:** copy-pasteable steps
**Tier:** T1 (automated) | T2 | T3
```

Rules that make it compound:

- **Written during development.** Every shipped feature adds its failure-mode entries in the same session (login → reset fails, token expiry, lockout; payments → failed charge, missed webhook).
- **Every T2 fix ends with a playbook append.** The system gets smarter weekly; known issues migrate to T1.
- Start with the 2–3 highest-impact flows, not everything. Each entry must be executable at 3 a.m. — copy-pasteable commands, no prose walls.
- A playbook is a library of pre-built red lamps.

## Rollout order (graybox: one behavior at a time)

Pilot on your product with real users first, then stamp thin versions onto internal tools:

1. **See** — PostHog level 1 + uptime pings → messenger. Verify: deliberately break the check once and watch the alert arrive (red lamp for the alert path itself).
2. **Alert** — error/rage webhooks with replay links. Verify: one deliberate error lands on your phone in under 5 minutes.
3. **Playbook** — top 3 flows documented; support entries become a shipping deliverable from here on.
4. **Agent loop** — error-tracker MCP (e.g. Sentry MCP) into your coding agent for full-context triage sessions.
5. **Tiers + incidents** — T3 playbook written; first T1 automation for whatever has recurred.
6. **Repeat** thin versions (uptime + errors, skip replay) for internal tools.

Each step is verified by *using* it before the next is added — never two new behaviors at once.
