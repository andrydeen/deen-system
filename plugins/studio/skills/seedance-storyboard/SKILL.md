---
name: seedance-storyboard
description: >
  Use this skill whenever the user wants to break a scene or story description into
  individual Seedance 2.0 shots with JSON output. Trigger on: "divide into shots",
  "create shot JSON", "generate storyboard", "break this scene into shots", "write
  Seedance prompts", "create storyboard JSON", or whenever a narrative is described
  and needs to be turned into production-ready Seedance 2.0 generation prompts.
  Also trigger when the user pastes a story in any language and asks for a shot list,
  shot breakdown, or JSON files. If the user describes a visual scene and mentions
  Seedance, JSON, or shots — this skill applies.
---

# Seedance 2.0 Storyboard Skill

Transforms a scene or story description into a complete storyboard: a numbered shot list
plus a JSON file per shot, ready for Seedance 2.0 generation. Every shot in the same
scene shares locked consistency anchors so the generated clips can be edited together.

---

## Step 0 — Collect reference assets BEFORE generating any JSON

Before writing a single shot, ask the user to provide reference assets. This is not
optional — the reference IDs are embedded directly into the shot JSONs, so you need them
upfront. Ask everything in ONE message, not spread across multiple rounds.

Build the asset request from what you've read in the story:

**Always ask for:**
- **Main character image(s)** — one reference photo per named character who appears
  in the scene. Example: "Please upload a reference image for Helen."
- **Environment/location image(s)** — one reference per distinct location in the scene.
  Example: "Please upload a reference image for the interior room (candlelit)."
  If there are two locations (interior + exterior), ask for both.

**Ask for only if relevant:**
- **Secondary character image(s)** — any named secondary character who appears in
  multiple shots (e.g., the kitten, a guard, an ally). A generic crowd or background
  person does not need a reference.
- **Source video** — if the user mentions that a shot should continue from an existing
  generated clip, or if they want to use a previously generated video as the starting
  frame. Ask: "Is any shot based on an existing video clip? If so, please upload it."

**Format your asset request like this:**

```
Before I generate the shot JSONs, I need a few reference assets to embed in the prompts:

1. Helen — reference image (character consistency across all shots)
2. Interior room (candlelit) — reference image (environment anchor for shots 1–12)
3. Dark exterior street — reference image (environment anchor for shots 13–20)
4. The kitten — reference image (character consistency)
5. Do you have any existing video clips any shot should continue from?
   If yes, please upload them too.

You can upload them now, or skip any you don't have yet — I'll note which shots
are missing references and you can add them later.
```

**Assigning reference IDs:**
As the user uploads assets, assign sequential IDs:
- Images: `image:1`, `image:2`, `image:3` … in upload order
- Videos: `file:81`, `file:82` … (Seedance uses file: prefix for video references)

Keep a reference map at the top of your output:
```
REFERENCE MAP
  image:1  →  Helen (character)
  image:2  →  Interior candlelit room (environment)
  image:3  →  Exterior dark street (environment)
  image:4  →  Kitten (character)
  file:81  →  [video clip name if provided]
```

If the user skips an asset, leave the reference field out of the JSON for those shots —
do not invent a placeholder. Note which shots are missing references at the end.

---

## Step 1 — Parse the input

The user may write in any language. Translate mentally as needed. Extract:

- **Characters** — who appears, their physical description, clothing, age
- **Locations** — distinct environments (interior room, exterior street, etc.)
- **Actions** — what happens, in what order
- **Dialogue** — exact words spoken, by whom
- **Tone/mood** — the emotional atmosphere the user describes

If the description is vague ("make it cinematic"), apply sensible defaults and note them.
If critical information is missing (e.g., no character description at all), ask one focused
question before proceeding.

---

## Step 2 — Define consistency anchors BEFORE writing any shots

Consistency anchors are values that stay locked across multiple shots. Define them once
at the top of your output. They fall into three levels:

### Project anchor (locked for the entire film/episode)
```
aspect_ratio: "16:9"          ← always confirm with user; default 16:9
resolution: "1280x720"        ← default; update if user specifies
style.grain: "fine film grain"
style.look: "cinematic realism, subtle filmic grain, high contrast chiaroscuro"
```

### Scene anchor (one per distinct location)
For each location in the scene, define:
```
color_palette: [...]           ← 3 dominant colors for this space
lighting.color_temperature:    ← e.g., "warm amber with cool blue fill"
lighting.mood:                 ← e.g., "quiet, tense, intimate"
scene.atmosphere:              ← e.g., "warm candlelight, floating dust particles"
```

Interior shots in the same room share the same scene anchor.
Exterior shots get their own anchor (typically darker, cooler, wider palette).

### Character anchor (one per recurring character)
Write a canonical subject line for each character that appears in more than one shot.
Use this EXACT string in every shot that character appears in.

Example:
```
Helen anchor: "Helen, 20-year-old woman in a black velvet period dress with white
pointed collar and white cuffs, dark hair, thoughtful eyes"

Kitten anchor: "small grey tabby kitten with bright amber eyes and alert ears"
```

The user defines these. If the user hasn't specified clothing or appearance, ask once
before generating all shots, because changing the anchor mid-storyboard breaks
character consistency.

---

## Step 3 — Divide the story into shots

A new shot begins when ANY of these change:
- Camera position or framing (wide → close-up, front → over-shoulder)
- Subject of focus (Helen → kitten → window)
- Location (interior → exterior)
- A significant tension shift (calm scene → sudden sound)
- A dialogue exchange requires showing the listener's reaction

A shot does NOT need to start every time a character speaks a new sentence. Dialogue
can run over a held shot. Only cut when the camera would actually cut.

Number shots sequentially: SHOT 01, SHOT 02, etc.

---

## Step 4 — Generate JSON for each shot

See `references/json-schema.md` for the full field reference.

**Every shot gets these core fields:**

```json
{
  "shot_id": "shot_01",
  "subject": "< character anchor or scene subject >",
  "action": "< what physically happens in this shot >",
  "scene": {
    "setting": "< physical description of the space >",
    "time_of_day": "< blue hour / late afternoon / night / etc. >",
    "atmosphere": "< from scene anchor >"
  },
  "shot": {
    "type": "< close-up / medium / wide / over-shoulder / etc. >",
    "angle": "< eye-level / low / high / etc. >",
    "lens": "< 35mm / 50mm / 85mm / etc. >",
    "framing": "< where characters sit in the frame >"
  },
  "camera": {
    "movement": "< dolly-in / push-in / static / orbit / etc. >",
    "speed": "slow"
  },
  "lighting": {
    "key": "< main light source and position >",
    "mood": "< from scene anchor >",
    "color_temperature": "< from scene anchor >"
  },
  "color_palette": [ "< from scene anchor >" ],
  "style": {
    "look": "< from project anchor >",
    "references": [],
    "grain": "< from project anchor >"
  },
  "duration_seconds": 6,
  "aspect_ratio": "< from project anchor >",
  "negative_prompt": "overexposed, motion blur, handheld jitter, modern props"
}
```

**Add extended fields when the shot involves:**

*Dialogue and audio (lip-synced speech):*
```json
"dialogue": {
  "speaker": "Helen",
  "language": "English",
  "text": "< exact spoken words >",
  "delivery": "calm, measured, slightly nostalgic",
  "lip_sync": true
},
"audio": {
  "include_dialogue": true,
  "spoken_by": "Helen",
  "voice": "female, 20s, calm, intelligent, soft British accent",
  "speech": "< same text as dialogue.text >",
  "ambient_sound": "< room ambience — candle crackle, room echo, street noise >",
  "music": "none"
}
```

*Reference images (character or environment consistency):*
```json
"references": {
  "character_image": "image:1",
  "environment_image": "image:2"
}
```

*Start frame (continue from a previous shot's last frame):*
```json
"start_frame": "file:81"
```
Use this when the shot is a continuation of the previous one and visual continuity
(same pose, same lighting state) is important.

*Explicit resolution (override project default):*
```json
"resolution": "1280x720"
```

**Duration guidelines:**
- Establishing shot: 6–8s
- Close-up reaction: 4–5s
- Dialogue shot: match the speech length + 1s padding
- Action beat (pressing clock, moving piece): 4–5s
- Wide exterior establishing: 6–10s

---

## Step 5 — Apply consistency anchors to every shot

Before finalising each shot JSON, check:
- [ ] `subject` uses the exact character anchor string (not a paraphrase)
- [ ] `color_palette` matches the scene anchor for this location
- [ ] `lighting.color_temperature` matches the scene anchor
- [ ] `aspect_ratio` matches project anchor
- [ ] `style.look` and `style.grain` match project anchor
- [ ] Exterior shots have their own anchor (don't inherit interior values)

If Helen appears in a shot alongside the kitten, her anchor goes in `subject` and the
kitten is described in `action` or `scene.setting`.

---

## Step 6 — Output format

First, print the **anchor block** so the user can review and correct before you generate all shots:

```
PROJECT ANCHORS
  aspect_ratio:   16:9
  resolution:     1280x720
  style.look:     cinematic realism, subtle filmic grain, high contrast chiaroscuro
  style.grain:    fine film grain

SCENE ANCHORS
  [Interior — candlelit room]
    color_palette:       ["burnt umber", "warm amber", "midnight blue"]
    lighting temp:       warm amber highlights, cool blue fill in shadows
    atmosphere:          warm candlelight, floating dust particles, deep shadows

  [Exterior — dark street]
    color_palette:       ["cold ash", "near-black", "dim sodium orange"]
    lighting temp:       cold ambient, faint sodium streetlight
    atmosphere:          near-total darkness, distant city sounds

CHARACTER ANCHORS
  Helen:    "Helen, 20-year-old woman in a black velvet period dress with white
             pointed collar and white cuffs, dark hair, thoughtful eyes"
  Kitten:   "small grey tabby kitten with bright amber eyes and alert ears"
```

Then print **each shot** as a titled section followed by its JSON:

```
---
SHOT 01 — Establishing the Room
[json block]

---
SHOT 02 — Close-Up of Helen
[json block]
```

Finally, wrap all shots in the **storyboard envelope**:

```json
{
  "storyboard_id": "storyboard_< episode_id >",
  "project": {
    "aspect_ratio": "16:9",
    "resolution": "1280x720",
    "style": "cinematic realism, fine film grain"
  },
  "shots": [ ...all shot objects... ]
}
```

---

## Handling partial input

If the user only describes some shots (e.g., shots 1–9 with JSON and shots 10–20 as
text only), generate JSON for the text-only shots using the established anchors.
Do not change anchors mid-scene unless the location changes.

If the user asks to add more shots later, confirm the existing anchors still apply
before generating the additions.

---

## Notes on the "story → shots" judgment

The goal is shots that can each be generated independently in Seedance 2.0 and then
edited together. That means:
- Each shot must make sense as a standalone 4–15 second clip
- The anchor system is what makes them feel like the same film
- When in doubt, cut more rather than less — shorter shots are easier to regenerate
- A shot that has too much happening (character walks across room AND reacts AND speaks)
  should be split even if the original story describes it as one moment
