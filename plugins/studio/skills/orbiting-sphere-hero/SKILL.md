---
name: orbiting-sphere-hero
description: >-
  Build a 3D orbiting-sphere hero page — an invisible Three.js sphere with flat
  image cards that orbit a centered logo, always facing the viewer (billboarding),
  with drag-to-rotate, hover-to-pop, and a soft click-to-open detail page that
  reverses on "back". Includes a dark/light theme toggle and a responsive mobile
  layout. USE THIS SKILL whenever the user wants an orbiting/rotating sphere of
  images, a "celestial mobile" or floating-photos hero, a 3D portfolio/landing
  hero where clicking an image opens a project/detail page, a Three.js image
  gallery sphere, or an Awwwards-style cinematic 3D hero — even if they don't name
  Three.js. A complete, working template is bundled; copy and customize it rather
  than rebuilding the orbit math from scratch.
---

# Orbiting Sphere Hero

A single-page, dependency-light hero where photos are mounted on flat cards that
orbit an invisible sphere around a centered wordmark. The feel is a quiet,
celestial mobile: images drift in space, always facing you, scaling and fading
with depth. Drag spins the sphere with momentum; hovering a card pops it forward;
clicking a card plays a soft transition into a two-column detail page, and a
"back" control reverses it. A dark/light toggle and a mobile layout are built in.

**The reliable path is the bundled template, not a from-scratch rebuild.** The
orbit distribution, billboarding, depth sorting, drag momentum, and the
two-phase open/close transition are fiddly to get right. `assets/sphere-hero.html`
is a complete, proven build. Copy it, then change the content, images, and brand.
Only rebuild from scratch if the user explicitly needs a different framework (see
`references/build-from-scratch.md`).

## Stack

- **Three.js** (loaded via CDN importmap — no build step, no npm)
- Vanilla ES-module JavaScript, single self-contained HTML file
- Google Fonts (Tenor Sans by default)
- Canvas 2D textures for the center logo and card shadows
- No bundler required; just serve the folder over HTTP

## Quick start

1. **Copy the template** into the project as `index.html`:
   ```bash
   cp <skill>/assets/sphere-hero.html index.html
   mkdir -p Visuals
   ```
2. **Add images** to `Visuals/` named `01.png`, `02.png`, … (square images look
   best — see "Images" below).
3. **Customize** the content data, brand, and tokens (see "Customization", which
   is the bulk of the work).
4. **Serve over HTTP and open** — never `file://` (ES modules + importmap require
   a server):
   ```bash
   python3 -m http.server 5180   # then open http://localhost:5180
   ```

## How it works (so you can adapt it confidently)

Read this before editing the JavaScript — it explains *why* the pieces exist.

- **Layering.** A fixed full-screen `<canvas id="scene">` (z-index 10) holds the
  WebGL sphere; the renderer clears transparent so the CSS `--bg` shows through
  (this is what makes the theme toggle recolor the backdrop for free). The
  `#project` detail page sits above at z-index 15.
- **The sphere is invisible.** Only the cards and the center logo are drawn.
  Cards are flat `PlaneGeometry` meshes positioned on a sphere surface via a
  **Fibonacci distribution** so they spread evenly instead of clustering at the
  poles.
- **Billboarding.** Every frame, each card is re-oriented to face the camera, so
  photos never look edge-on. This is continuous (lerped), not snapped.
- **Depth cues.** Cards toward the front are scaled up and fully opaque; cards
  toward the back shrink and fade. This sells the 3D volume more than the orbit
  alone.
- **Idle + drag.** The sphere auto-rotates slowly (about one revolution per 50s)
  and each card bobs on a sine wave with a random phase. Pointer drag rotates the
  sphere (horizontal = spin, vertical = limited tilt) and releases into a
  friction-based momentum ease back to idle.
- **Open transition (`enterProject`).** Two phases: (1) the other cards and the
  center logo fade out while the clicked card freezes; (2) that card hands off to
  a DOM `<img>` that flies to the right column and scales up, then the left-column
  text cascades in. `returnToHero` reverses it exactly.
- **Center logo & card shadows are canvas textures**, not CSS — so CSS variables
  can't recolor them. `drawLogoText()` and `drawShadow()` repaint those canvases
  on theme change and set `needsUpdate = true`. If you change the logo text or
  theme colors, edit those two functions.

## Customization

Almost everything you change lives in clearly marked spots. Search for these
anchors in `index.html` rather than relying on line numbers (they shift):

### 1. Content data — `const SERVICES` (the detail pages)
This array drives what opens when a card is clicked. One entry per image, in
orbit order. Each entry:
```js
{ title: 'AI Receptionist',          // detail-page H1 + card project name
  eyebrow: 'Always On',              // small uppercase label
  p1: 'First paragraph…',            // two body paragraphs
  p2: 'Second paragraph…' }
```
`PROJECT_NAMES` is derived from it automatically. Keep the array length equal to
the number of images.

### 2. Images — `const IMAGES` + the `Visuals/` folder
The default maps twelve files: `Visuals/01.png … 12.png`. To use a different
count, edit the `IMAGES` array (the `['01','02',…]` list). **Use square images**
— the cards are 1:1 (`CARD_W === CARD_H`) so square art is shown uncropped. Other
aspect ratios get center-cropped by `object-fit: cover`; if you need that, change
`CARD_W`/`CARD_H` to your ratio and the project-image rect in `computeImageRect`.

### 3. Brand wordmark (four places)
- `<title>` in `<head>`
- `.nav-brand` (desktop) and `.nav-brand-mobile` text in the nav markup
- the **center sphere logo**: `drawLogoText()` → `ctx.fillText('DE:N', …)`

### 4. Colors & fonts — the `:root` token blocks
`:root, :root[data-theme="dark"]` is the dark palette; `:root[data-theme="light"]`
is the light one. Tokens: `--bg --surface --nav-text --divider --logo --accent
--body-text`. The light logo/shadow colors are also hardcoded in `drawLogoText()`
and `drawShadow()` — keep them in sync if you change the palette. Swap the Google
Fonts `<link>` and the `--font*`/`font-family` rules to change typefaces.

### 5. Motion & layout knobs — the `// Config` block
- `CARD_W`, `CARD_H` — card size (keep equal for square art)
- `SPHERE_RADIUS_FRAC` (default `0.40`) — orbit radius as a fraction of the
  smaller viewport dimension; larger = cards reach closer to the edges
- `SPHERE_Y_FACTOR` (default `0.60`) — vertical squash of the orbit
- `MOBILE_BREAK` / `TABLET_BREAK` — responsive breakpoints
- `MOBILE_ROLL` — how far the orbit tilts toward vertical on phones
- Idle rotation speed (~one rev/50s) and bob amplitude live in the animation loop

### 6. Nav links and the theme toggle
Nav labels are placeholders (`Home`, `Blog`, `Services`, `Contact`) with neutral
`href="#"`. Point them at real pages or remove them. The theme toggle works out
of the box and persists to `localStorage['sphere-theme']`; a pre-paint script in
`<head>` applies the saved theme with no flash. Default is dark.

## Gotchas (these will bite otherwise)

1. **Serve over HTTP.** The ES-module `<script>` + importmap and the image
   textures do not work from `file://`. Use a dev server.
2. **Square images avoid cropping.** Cards are 1:1; non-square art is cropped.
3. **Theme recolors canvas textures via JS, not CSS.** The center logo and card
   shadows are drawn on canvases — recolor them in `drawLogoText`/`drawShadow`,
   not the stylesheet.
4. **Internet is required** (Three.js + Google Fonts come from CDNs). For an
   offline/self-hosted build, vendor `three.module.js` locally and update the
   importmap, and self-host the fonts.
5. **Headless screenshot tools may capture black** at non-zero state because of
   the fixed WebGL canvas — verify with the DOM/console, not just a screenshot.
6. **Keep `SERVICES` length === image count**, or clicking late cards wraps via
   the modulo and shows the wrong copy.

## Verifying it works

- Page + every image return HTTP 200 over the dev server.
- Cards bloom in on load, then orbit slowly and bob.
- Drag spins the sphere and releases with momentum.
- Hovering a card pops it forward; clicking flies it into the detail page.
- The "back" control / Esc returns to the sphere with the reverse transition.
- The theme toggle flips the backdrop, nav, logo, and card shadows together.
- Resize keeps the sphere centered and the detail layout aligned.

## Building from scratch (only if a different framework is required)

If the user needs React, Vue, Svelte, raw WebGL, etc., the bundled template can't
be copied verbatim. `references/build-from-scratch.md` has the original
section-by-section prompt walkthrough (hero → transition → mobile) that produced
this build, so you can reconstruct it in another stack while preserving the same
behavior and pitfalls.
