# Starting a New Project — Step-by-Step Guide

This guide takes you from "I have an idea" (or "I have a specification document") all the way to a live, working product — using the tools installed with the Deen System setup. Follow it top to bottom. Every command you need is written out exactly as you should type it.

**How to read this guide:**
- Anything starting with `/` (like `/gsd:new-project`) is a command you type **into the Claude Code chat**, not the terminal.
- Anything in a grey block without `/` is either a terminal command or a plain-English message to Claude — it will say which.
- You never need to memorize commands. **When in doubt, just tell Claude what you want in plain English** ("I have an idea for an app, help me start") — Claude knows this workflow and will run the right commands for you.

---

## Part 0 — One-time setup (do this once, ever)

Skip this part if you've already done it.

1. Install Claude Code and open a terminal.
2. Install the Deen plugin (type into Claude Code chat):
   ```
   /plugin marketplace add andrydeen/deen-system
   /plugin install deen@deen-system
   ```
3. Run the setup and answer its questions:
   ```
   /deen:setup
   ```
   When it offers to install the recommended stack (**Superpowers, GSD, SDD, GStack**, Context7, Playwright), say yes — this guide uses all of them: Superpowers and GSD from day one, SDD after your product goes live, GStack for reviews and QA.
4. Restart Claude Code (newly installed plugins only load on restart), then verify everything works:
   ```
   /deen:verify
   ```

---

## Part 1 — What do you have? (pick your starting point)

| Your situation | Go to |
|---|---|
| Just an idea in my head, still fuzzy | **Part 2** (sharpen the idea) |
| A written specification document (Word, PDF, markdown) | **Part 3** (create the project) |
| A small task, under one day of work (fix, tweak, tiny tool) | **No framework needed.** Just describe the task to Claude and let it work. Skip to Part 7 for the session rules. |
| A new feature for a product that is already live | **Part 6** (SDD feature pipeline) |

---

## Part 2 — You have only an idea: sharpen it first (~30 minutes)

Do not start building from a fuzzy idea. Spend 30 minutes turning it into a one-page document — this is the highest-value half hour of the whole project.

1. Open a terminal in any folder and start Claude Code (`claude`).
2. Say to Claude, in plain English:
   > Let's brainstorm an idea I have: [describe your idea in 2–3 sentences]
   Claude will use its brainstorming skill: it asks you questions one at a time about who it's for, what problem it solves, and what "done" looks like. Answer honestly; say "I don't know" when you don't.
3. **For a big commitment** (something you'll spend weeks on), use the tougher interviewer instead:
   ```
   /grill-me
   ```
   It will pressure-test your idea until every gap is found.
4. When the conversation feels complete, say:
   > Save what we agreed as IDEA.md — one page: what it is, who it's for, what problem it solves, what version 1 must include, what's explicitly NOT included.
5. You now have `IDEA.md`. Continue to Part 3, using `IDEA.md` as your document.

---

## Part 3 — Create the project and generate the plan

You have a document now — either your `IDEA.md` or a specification someone gave you.

**Step 1 — Create the project folder.** Say to Claude:
> Create a new project folder called [project-name] in my Projects directory, set up git in it, and move my document there.

(Or do it yourself in the terminal: `mkdir ~/Projects/my-project && cd ~/Projects/my-project && git init`, then copy your document in and run `claude`.)

**Step 2 — If your specification is a Word file or PDF**, convert it first. Say to Claude:
> Convert @MySpec.docx into a clean markdown file called SPEC.md

**Step 3 — Bootstrap the project with GSD.** This is the big one — it interviews you, researches the domain, writes requirements, and produces a phased roadmap:
```
/gsd:new-project @SPEC.md
```
(Use `@IDEA.md` if you came from Part 2. If your document is complete and detailed, add `--auto` at the end and it will run with fewer questions: `/gsd:new-project @SPEC.md --auto`)

**What you get:** a `.planning/` folder in your project containing the requirements, a roadmap split into phases, and a state file that remembers progress between sessions. This roadmap is now the single source of truth for *what* gets built and *in what order*.

---

## Part 4 — Pressure-test the plan before building (recommended)

Building from a flawed plan wastes days. Reviewing the plan costs minutes.

1. First, create the detailed plan for phase 1:
   ```
   /gsd:plan-phase 1
   ```
2. Then run the automatic review board over it:
   ```
   /autoplan
   ```
   This reads your plan through four different lenses — CEO (is this the right scope?), engineering (will it work?), design (is it usable?), developer experience — and fixes problems automatically using sensible decision rules.
3. Read the summary it produces. If something important changed, glance at the roadmap once more before continuing.

---

## Part 5 — Build it, phase by phase

This is the main loop. Repeat it for every phase in your roadmap (a typical project has 2–7 phases):

```
/gsd:plan-phase 1        ← detailed plan for this phase (skip if done in Part 4)
/gsd:execute-phase 1     ← Claude builds everything in the phase
/gsd:verify-work         ← checks the phase actually achieved its goal
```

Then the same for phase 2, phase 3, and so on.

**Good to know while building:**
- You don't need to babysit `/gsd:execute-phase` — it commits work step by step and stops to ask when it genuinely needs your decision.
- Check where you are at any time: `/gsd:progress`
- Came back after a break and lost the thread? `/gsd:resume-work`
- Something is broken and you don't know why? Say "debug this" or run `/gsd:debug` — never let Claude guess-and-retry; the debugging skill finds the actual cause first.
- Discipline (writing tests first, verifying before claiming done) is automatic — the Superpowers skills fire on their own during execution. You don't run them manually.

**When the last phase passes verification:**
```
/gsd:complete-milestone
```

---

## Part 6 — Ship it, then switch to feature mode

**Ship version 1:**
1. Test it like a user, not like a builder. Say to Claude:
   > Run /qa on the app and show me what a first-time user experiences.
2. Deploy. Say to Claude:
   > Deploy this to Vercel production.
   (or your hosting of choice — Claude handles the details)
3. Confirm the deployed product actually works — open the real URL and click through it once yourself.

**After it's live — the important switch:** stop using GSD phases for new work. GSD is for *getting to version 1*. Once the product exists, every new feature goes through the **SDD pipeline** instead (already installed as part of your setup). Once per project, map the codebase:
```
/sdd:survey
```
Then, for **each** new feature (replace `my-feature` with a short name):
```
/sdd:specify my-feature      ← interview → written spec
/sdd:clarify my-feature      ← finds and resolves every ambiguity in the spec
/sdd:design my-feature       ← architecture document
/sdd:tasks my-feature        ← breaks it into small tasks
/sdd:implement my-feature    ← builds it, test-first
/sdd:review my-feature       ← independent code review
/sdd:ship my-feature         ← final checks + pull request
```
If a feature touches the database or an API, SDD will tell you it needs extra steps in between (`data-model`, `api`, `plan-tests`) — just run the command it names. To see what's planned across all features: `/sdd:roadmap`

**The one rule that prevents chaos:** never run GSD planning and SDD on the same piece of work. GSD owns the whole project skeleton; SDD owns one feature at a time.

---

## Part 7 — Session rules (every session, every project)

**Ending a session — always, no exceptions:**
```
/deen:handoff
```
This saves a compact note of what was done, updates the project's overview, and makes next session's startup instant. If you skip it, the next session starts half-blind.

**Starting a session:**
```
/deen:handoff
```
The same command at the start of a session restores context — Claude reads the overview and tells you where you left off and what's next. Then just say what you want to work on.

---

## Quick reference card

| I want to… | Type |
|---|---|
| Sharpen a fuzzy idea | "Let's brainstorm: …" (or `/grill-me` for big commitments) |
| Start a project from a document | `/gsd:new-project @SPEC.md` |
| Review the plan before building | `/gsd:plan-phase 1` then `/autoplan` |
| Build the next phase | `/gsd:plan-phase N` → `/gsd:execute-phase N` → `/gsd:verify-work` |
| See project status | `/gsd:progress` |
| Continue after a break | `/gsd:resume-work` |
| Fix a bug properly | `/gsd:debug` |
| Finish version 1 | `/gsd:complete-milestone` |
| Add a feature to a live product | `/sdd:specify <name>` → follow the chain in Part 6 |
| Do a small task (< 1 day) | Just describe it to Claude — no framework |
| End (or start) any session | `/deen:handoff` |
| Check my setup is healthy | `/deen:verify` |

**And the golden rule once more:** if you forget every command on this page, just tell Claude what you want in plain English and mention this guide — "I have an idea, walk me through starting a project the Deen System way." It will do the rest.
