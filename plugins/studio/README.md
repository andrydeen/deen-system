# studio — web design & AI video toolkit

Four skills for building distinctive websites and AI-generated video, extracted from real client work.

```
/plugin install studio@deen-system
```

| Skill | Trigger it with | What you get |
|---|---|---|
| **orbiting-sphere-hero** | "build an orbiting sphere hero site" | A complete 3D hero website (Three.js, no build step): services orbit a sphere as cards, click opens a detail page. Ships as a working template + customization map (brand colors, fonts, content data) + from-scratch reference. |
| **re-walkthrough-pro** | "make a walkthrough video from this listing" | Property listing → cinematic room-by-room walkthrough video: scrape listing photos (Apify), animate each room (Higgsfield image-to-video), stitch with crossfades + music (ffmpeg). Built to sell to real-estate agents. |
| **seedance-storyboard** | "storyboard this scene for Seedance" | Structured storyboards for Seedance 2.0 generation — shot list, camera moves, continuity notes. |
| **video-prompt-builder** | "write video prompts from this brief" | A creative brief → detailed shot-by-shot AI video prompts (Seedance 2.0 dialect), consistent style across shots. |

## Bring your own accounts

These skills orchestrate external services — you supply the accounts/keys where needed:

- **Higgsfield** (re-walkthrough-pro): image-to-video generation. Higgsfield access on claude.ai, or their platform directly.
- **Apify** (re-walkthrough-pro): listing scraping — free tier works; the skill tells you where the token goes.
- **ffmpeg** (re-walkthrough-pro): `brew install ffmpeg`.

No keys or accounts are bundled — nothing runs against the author's services.

## Companion tools (install separately)

The full creative stack, including third-party skills that pair well with these, is documented in [docs/creative-stack.md](../../docs/creative-stack.md).
