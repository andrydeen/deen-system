# Building the orbiting sphere from scratch

Use this only when the bundled `assets/sphere-hero.html` can't be copied verbatim
(e.g. the user needs React/Vue/Svelte/raw WebGL). It is the section-by-section
spec that produced the template. Build one section at a time and approve each
before moving on — the transition depends on a finished, stable hero.

Pair a detailed text spec with a reference image when you can: the text describes
behavior, the image locks the look.

---

## Prompt 1 — The hero (the orbiting sphere)

Build a full-screen hero centered on an **invisible 3D sphere**. Portfolio images
are mounted on flat rectangular cards that orbit the sphere slowly, always
rotating to face the user (**billboarding**). The effect should feel like a quiet,
celestial mobile — images drifting in space with graceful, continuous motion. The
user can drag to rotate; hovering a card pauses it and brings it forward. Mood:
meditative, elevated, slightly otherworldly.

**Navigation bar.** Fixed top bar: left = two text links, center = brand wordmark,
right = two text links. Uppercase, generous letter-spacing (~0.25em). A 1px
hairline divider sits below, inset to align with the outer links (not full bleed).

**The sphere.** Centered in the viewport below the nav. Radius ≈ 38–40% of the
viewport's smaller dimension — large enough that cards reach close to the edges
but never clip.

**Image cards.** Use all N images. Distribute them with a **Fibonacci spiral**
across the sphere surface so they don't cluster at the poles. Each card ~square
(or your chosen aspect) with a very subtle drop shadow.

**Center logo.** The wordmark renders inside the sphere at the sphere's center
*depth* — so it appears behind cards on the front half and in front of cards on
the back half. Large, the brand typeface.

**Animations.**
- *Load:* background fades in; cards materialize one by one (fade 0→1, scale
  0.7→1 over ~0.6s, each ~0.12s after the previous, in spiral order so they bloom
  outward); nav and center logo fade in after the first few cards.
- *Idle:* sphere rotates on its vertical axis, ~one revolution / 50s. Each card
  bobs ±~6px on a sine wave (~4s period) with a per-card phase offset.
  Billboarding is continuous, not snapping.
- *Drag:* pointer drag rotates the sphere (horizontal = spin around vertical axis;
  vertical = tilt, clamped to ~±25°). On release, decelerate with a friction-based
  momentum curve back to idle over ~3s.
- *Hover:* hovered card scales to ~1.15, translates ~40px toward the camera, and
  its shadow deepens; it temporarily detaches from the rotation and holds. On
  mouse-out it eases back over ~0.6s.

**Depth realism (do this — it's what sells the 3D):** scale each card by its
position on the sphere (front larger, back smaller) and add an opacity falloff
(front fully opaque, back more transparent).

**Suggested design tokens** (adapt to brand): warm off-white bg `#F5F1EC`, nav
text `#404040`, divider `#D9D9D9`, logo ink `#1E1B18`; idle card shadow
`0 4px 20px rgba(42,37,32,.08)`, hover `0 12px 40px rgba(42,37,32,.15)`. Display
typeface with generous tracking (e.g. Tenor Sans).

---

## Prompt 2 — The transition & detail page (click to open)

Only after the hero is finished. Clicking a card opens a project/detail page;
don't modify the hero, orbit, drag, hover, or nav.

**Layout.** Two columns: text on the left (~40–45% width), the clicked image on
the right.

**Open transition, two phases:**
- *Phase 1 (~0.6s):* all other cards fade to 0; the center logo fades to 0; the
  clicked card freezes in place (orbit + bob stop). Only the nav and that one card
  remain.
- *Phase 2 (~1.8s):* (A, 0–1.0s) the clicked card hands off to a DOM image that
  animates from its sphere position to the right column, scaling up to fill the
  column height with correct padding, shadow fading out, ease-in-out. (B, after A)
  the left text fades in top-to-bottom with a fade + slide-up (~20px), each element
  starting ~0.15s after the previous: title → eyebrow → paragraph 1 → paragraph 2.

**Return.** A back/close control (and Esc) reverses it: text fades out + slides
down in reverse order (~0.4s); the image shrinks back to its sphere card position
(~0.8s, ease-in-out); then the other cards and center logo fade back in (~0.5s)
and the orbit resumes.

**Data.** Each image maps to an entry with a title, an eyebrow label, and two body
paragraphs. Keep the data array length equal to the image count.

---

## Prompt 3 — The mobile version (responsive)

Apply only below the desktop breakpoint; don't change desktop behavior.

- **Breakpoints:** desktop ≥1024px (unchanged), tablet 768–1023 (transitional),
  mobile <768.
- **Nav:** brand left, hamburger right; the four links move into a full-screen
  overlay menu (fade/slide from the right, opaque bg) that sits above everything.
- **Sphere:** tilt the orbital axis ~70–80° so the path becomes a tall ellipse
  (cards sweep more vertically). Same idle speed, bob, and drag. Allow ~20–30% of
  a card to bleed off the top/bottom edges; `overflow: hidden` on the container.
  Smaller cards and a radius ~45–50% of viewport width.
- **Detail page:** single column, vertically scrollable. Same two-phase
  transition, adapted: the tapped card animates to the top (full width minus
  padding, ~50–60vh), then text fades in below it.

---

## Hard-won lessons

- A reference image plus a detailed text spec is the most reliable combo.
- Build one section at a time; finish each before the next. Use branches for risky
  steps.
- Bundle related fixes into one follow-up rather than many tiny ones.
- Keep the center logo at the sphere's center *depth*, not behind everything, or
  the front cards won't pass in front of it.
- Ask for exact pixel measurements when fine-tuning spacing.
