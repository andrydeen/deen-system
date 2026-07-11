# Seedance 2.0 Shot JSON — Full Field Reference

## Core fields (required in every shot)

| Field | Type | Description |
|---|---|---|
| `shot_id` | string | Sequential ID: "shot_01", "shot_02" |
| `subject` | string | Who or what the camera is primarily on. Use character anchor exactly. |
| `action` | string | What physically happens in this shot — movement, gesture, expression. |
| `scene.setting` | string | Physical description of the space. |
| `scene.time_of_day` | string | blue hour / late afternoon / night / interior / etc. |
| `scene.atmosphere` | string | Sensory atmosphere — light quality, particles, sounds implied. |
| `shot.type` | string | extreme close-up / close-up / medium close-up / medium / wide / establishing / over-the-shoulder |
| `shot.angle` | string | eye-level / low angle / high angle / slightly low / bird's eye |
| `shot.lens` | string | 35mm / 50mm / 85mm / 85mm macro / 50mm cine / etc. |
| `shot.framing` | string | Where the subject sits in frame — "face fills frame", "left third", etc. |
| `camera.movement` | string | static / slow dolly-in / push-in / pull-back / orbit clockwise / rack focus / slow descend |
| `camera.speed` | string | slow / medium / fast |
| `lighting.key` | string | Main light source and position. |
| `lighting.mood` | string | Emotional quality of the light. From scene anchor. |
| `lighting.color_temperature` | string | e.g., "warm amber with cool blue fill". From scene anchor. |
| `color_palette` | array | 3 dominant color names. From scene anchor. |
| `style.look` | string | Visual style descriptor. From project anchor. |
| `style.references` | array | Filmmaker/film references for tone. Can be empty []. |
| `style.grain` | string | Film grain description. From project anchor. |
| `duration_seconds` | integer | Clip length in seconds. |
| `aspect_ratio` | string | From project anchor. Default "16:9". |
| `negative_prompt` | string | What to avoid. Always include: overexposed, handheld jitter, modern props. |

---

## Extended fields (add when relevant)

### start_frame
Use when this shot should visually continue from the end of a previously generated clip.
The ID comes from the reference map (file:81, file:82, etc.) assigned when the user
uploads a video in Step 0.
```json
"start_frame": "file:81"
```
Only use when the user explicitly wants visual continuity from a specific existing clip.
Do not add this field speculatively.

### references
Use when you have reference images to anchor character appearance or environment.
These IDs come from the reference map built in Step 0 when the user uploads assets.
```json
"references": {
  "character_image": "image:1",
  "environment_image": "image:2"
}
```
Rules:
- `character_image` — the reference for the primary subject of this shot
- `environment_image` — the reference for the location this shot takes place in
- If a shot has two characters (e.g., Helen + kitten), use `character_image` for the
  primary subject and describe the secondary in `action` or `scene.setting`
- Can include just one field if only one reference is available
- Never invent an image ID — only use IDs from the reference map

### resolution
Override the project default resolution for this specific shot.
```json
"resolution": "1280x720"
```
Common values: "1280x720" (720p), "1920x1080" (1080p), "768x1280" (9:16 vertical)

### dialogue
Use when a character speaks on camera with lip sync.
```json
"dialogue": {
  "speaker": "Helen",
  "language": "English",
  "text": "The exact words spoken.",
  "delivery": "calm, measured, slightly nostalgic",
  "lip_sync": true
}
```
`delivery` descriptors: calm / urgent / whispered / dry / sad / amused / tense

### audio
Accompanies `dialogue` when present. Also used for ambient-only shots.
```json
"audio": {
  "include_dialogue": true,
  "spoken_by": "Helen",
  "voice": "female, 20s, calm, intelligent, soft British accent",
  "speech": "< same as dialogue.text >",
  "ambient_sound": "quiet room ambience, candle crackle, subtle echo",
  "music": "none"
}
```
For shots without dialogue: omit `include_dialogue`, `spoken_by`, `voice`, `speech`.
```json
"audio": {
  "ambient_sound": "distant city, metal on stone, wind",
  "music": "none"
}
```

---

## Storyboard envelope

Wraps all shots for a scene or episode.

```json
{
  "storyboard_id": "storyboard_helen_ep01_scene001",
  "project": {
    "aspect_ratio": "16:9",
    "resolution": "1280x720",
    "style": "cinematic realism, fine film grain, high contrast chiaroscuro"
  },
  "characters": {
    "Helen": "Helen, 20-year-old woman in a black velvet period dress with white pointed collar and white cuffs, dark hair, thoughtful eyes",
    "Kitten": "small grey tabby kitten with bright amber eyes and alert ears"
  },
  "scenes": {
    "interior_room": {
      "color_palette": ["burnt umber", "warm amber", "midnight blue"],
      "lighting_temperature": "warm amber highlights, cool blue fill in shadows",
      "atmosphere": "warm candlelight, floating dust particles, deep shadows"
    },
    "exterior_street": {
      "color_palette": ["cold ash", "near-black", "dim sodium orange"],
      "lighting_temperature": "cold ambient, faint sodium streetlight",
      "atmosphere": "near-total darkness, distant city sounds"
    }
  },
  "shots": []
}
```

---

## Shot type reference

| Type | When to use |
|---|---|
| establishing / wide | Opening a location for the first time |
| medium-wide | Two characters visible, environment readable |
| medium | Waist-up, character interaction |
| medium close-up | Chest-up, expression readable, dialogue |
| close-up | Face fills most of frame, strong emotion |
| extreme close-up | Eyes, hands, small objects — maximum detail |
| over-the-shoulder | One character's POV toward another |
| insert / detail | Object close-up — chess piece, clock button, window latch |

## Camera movement reference

| Movement | Effect |
|---|---|
| static | Stillness, weight, tension |
| slow dolly-in | Intimacy building, focus on character |
| slow pull-back / dolly-out | Reveal, isolation, dread |
| orbit / arc | Character study, 3D presence |
| rack focus | Shift attention between subjects |
| slow descend | Reveal what's below, dread |
| slow ascend | Reveal scale, hope or threat |
| push-in | Urgency, closing in |
