# The creative stack: building websites and AI video

If your work includes **websites** or **AI-generated video**, this is the toolkit. It has two halves: the **`studio` plugin** from this marketplace (our own skills), and **third-party skills** you install from their authors (listed here with exact commands — we don't redistribute other people's work).

## Half 1 — the `studio` plugin (this marketplace)

```
/plugin install studio@deen-system
```

Four skills: `orbiting-sphere-hero` (3D hero website template), `re-walkthrough-pro` (property listing → walkthrough video), `seedance-storyboard`, `video-prompt-builder`. Details and the bring-your-own-accounts list: [plugins/studio/README.md](../plugins/studio/README.md).

## Half 2 — third-party creative skills (install from source)

### Web design

- **ui-ux-pro-max** — design intelligence: 50+ styles, 161 palettes, 57 font pairings, UX guidelines, per-stack guidance (React/Next/Tailwind/…). Large but worth it for any UI work.
  ```bash
  npx ui-ux-pro-max install   # or see its repo for the current install command
  ```
- **gstack design suite** (part of the gstack install from the main README): `/design-shotgun` (generate multiple design variants + comparison board), `/design-html` (production-quality HTML/CSS finalization), `/design-review`, `/diagram`. If you installed gstack, you already have these.
- **frontend-design** (Anthropic, in claude-plugins-official) — distinctive visual direction guidance, ships with Claude Code plugins:
  ```bash
  claude plugin install frontend-design@claude-plugins-official
  ```

### AI video & images

- **higgsfield-ai-prompt-skill** (OSideMedia) — prompt engineering for Higgsfield generation models:
  ```bash
  git clone https://github.com/OSideMedia/higgsfield-ai-prompt-skill ~/.claude/skills/higgsfield
  ```
- **Higgsfield on claude.ai** — if your Claude plan has the Higgsfield connector, image/video/audio generation tools are available directly in sessions (no local setup).
- **imagen-generator** — plain-English image generation via Google Imagen:
  ```bash
  git clone https://github.com/andrydeen/imagen-generator ~/.claude/skills/imagen-generator
  ```
  (needs a Google AI API key — the skill explains where it goes)
- **ffmpeg** — the video glue everything relies on: `brew install ffmpeg`

## How the halves work together (a real pipeline)

The walkthrough-video product works like this: `re-walkthrough-pro` (studio) scrapes the listing and orchestrates → Higgsfield animates each room photo → `ffmpeg` stitches with crossfades and music. A website job works like: `ui-ux-pro-max`/`frontend-design` for design direction → `orbiting-sphere-hero` (studio) or `/design-shotgun` (gstack) for the build → `/qa` + Playwright MCP to verify in a real browser.

## Ground rules

- **Bring your own keys** — Apify, Higgsfield, Google AI. Nothing in the studio plugin runs against the author's accounts.
- **Graybox order applies to creative work too**: get the mechanic working with placeholder media first (one room, one gray box, one test shot), verify, then run the full generation — AI video credits are the expensive part.
