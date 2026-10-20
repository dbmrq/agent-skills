---
name: ios-app-store-creative-assets
description: >-
  Generate and publish App Store creative assets — product page header and search
  results images plus seamless looping videos — with deterministic minimal
  renders, an optional AI backdrop, and App Store Connect Asset Library upload
  and placement through the API. Use when asked for store header/search artwork,
  animated App Store assets, the Asset Library, creative assets for a new app,
  or porting this pipeline to a sibling app.
---

# iOS App Store Creative Assets

Header + search-results artwork for the product page (iOS 27+). **Not** screenshots
or app previews — those stay in [ios-app-store-screenshots](../ios-app-store-screenshots/SKILL.md).

Reference implementation: Sandow `scripts/creative_assets.py`,
`scripts/upload_creative_assets.py`, `store-assets/creative/<app>.yaml`.

## Specs (ASC, iOS 27 era)

| Placement | Image | Video |
|-----------|-------|-------|
| Product page header | 3840 × 1646 (21:9, PNG) or universal 5244 × 2950 (16:9, PNG) | 3840 × 1646, 5–30 s, 30/60 fps, H.264 `.mp4/.mov/.m4v`, muted, loops |
| Search results | 3:2, 1920–3840 × 1280–2560 (PNG/JPG) or universal | 5–30 s, 30/60 fps, muted (cannot unmute), loops |

No alpha. One placement per placement type (`maxCount` 1) — place the video
(animated) or the image, not both. Assets are reviewed separately from the app
(they can ride with the version or be submitted from the Asset Library).

## Repo pieces

```
store-assets/creative/<app>.yaml     # brand, copy, sizes, motion, UI shot, motif
store-assets/creative/art/<mark>.png # rasterized app-icon mark for the motif
store-assets/creative/out/           # header/search .png + .mp4 + previews
scripts/creative_assets.py           # renderer (stills, videos, previews, styles)
scripts/generate_creative_art.py     # optional AI backdrop (headless image model)
scripts/upload_creative_assets.py    # Asset Library upload + placement
scripts/submit_creative_assets.py    # submit assets for review (live apps)
```

## Workflow

```bash
# 1. preview design changes cheaply (4 key frames + contact sheet per placement)
python3 scripts/creative_assets.py --format still --preview

# 2. compare motif treatments when unsure (glass | soft | outline)
python3 scripts/creative_assets.py --style-sheet

# 3. final stills + seamless loops (prints loop-seam vs frame-step)
python3 scripts/creative_assets.py

# 4. upload + place the animated asset (replaces the existing placement)
python3 scripts/upload_creative_assets.py --version 1.0 --placement header \
  --image store-assets/creative/out/header.png --video store-assets/creative/out/header.mp4 --replace
python3 scripts/upload_creative_assets.py --version 1.0 --placement search \
  --image store-assets/creative/out/search.png --video store-assets/creative/out/search.mp4 --replace

# fallback stills only (no placement change)
python3 scripts/upload_creative_assets.py --version 1.0 --placement header \
  --image store-assets/creative/out/header.png --no-place
```

API details and traps: [references/api.md](references/api.md).

## Live apps: review the assets before placing them

A version that is already `READY_FOR_SALE` rejects a placement whose asset is not
approved yet:

```
409 ENTITY_ERROR.RELATIONSHIP.INVALID
"The asset must be in the APPROVED state because the parent is already approved."
```

So for a live app (no editable version) the order is **upload → review → place**:

```bash
# 1. upload without touching the placement (the still stays as a fallback)
python3 scripts/upload_creative_assets.py --version 1.2 --placement header \
  --image store-assets/creative/out/header.png \
  --video store-assets/creative/out/header.mp4 --no-place

# 2. submit the uploaded assets to App Review on their own
python3 scripts/submit_creative_assets.py           # create + submit a submission
python3 scripts/submit_creative_assets.py --wait    # poll until APPROVED

# 3. place the approved videos by id (no re-upload)
python3 scripts/upload_creative_assets.py --version 1.2 --placement header \
  --video-id <asset-id> --replace
```

Assets move `READY_FOR_REVIEW → WAITING_FOR_REVIEW → IN_REVIEW → ACCEPTED →
APPROVED`; only `APPROVED` can be placed on an already-approved parent. On a
**pre-submission** version the assets ride along with the version submission and
the placement reports `ACTIVE` immediately — no separate review needed. If the
asset is already in an independent review submission, you can still place it on
a `PREPARE_FOR_SUBMISSION` version while it is `WAITING_FOR_REVIEW`; the
placement shows `ACTIVE` and both reviews proceed.

**One placement per placement type:** place the video *or* the still, never both.
Keep the still in the library as the fallback.

## Design recipe that works (minimal)

- **Two text elements only**: app wordmark + one headline. Large type, tight
  tracking (tracking ≈ 10% of wordmark size, *not* 25%); skip sublines.
- **Generous insets** (~10% horizontal). It is easy to make this too tight; leave
  real empty space around the block.
- **One real UI card** anchored right, **~25% cropped below the frame** so the
  interface reads large without shrinking the copy.
- **Motif**: rasterize the app icon (Inkscape) into a huge, soft middle layer.
  The **glass** treatment (translucent white fill + subtle top sheen, **no stroke**,
  faint lift shadow) reads best on a light background; increase fill opacity
  until it is clearly visible. `soft` reads like a shadow; `outline` is too faint.
- **Background**: deterministic — cool diagonal gradient + soft glow + fine grain.
  Match the app's UI palette (cool gray-blue, not beige). No AI needed for this.
- **Motion**: one phase for all layers, different amplitudes (e.g. texture ±10 px,
  motif ±90 px, foreground text+card ±24 px). Text and screenshot must move as a
  **single block** — never independent/random motion. Slower is better: 10–14 s
  loops. Use fractional bicubic offsets; integer truncation stair-steps and reads
  as jitter. Keep every motion periodic; the renderer prints
  `loop-seam ≈ step` when the loop connects.

## Headless models

- **Image generation**: OpenRouter models are available in the OpenCode catalog
  (Nano Banana 2 Lite / Pro, Gemini 3.1 Flash Image, GPT-5.4 Image 2). Use them for
  abstract backdrop art only — never text or UI. `scripts/generate_creative_art.py`
  reads `OPENROUTER_API_KEY` or the OpenCode auth store; cache output in
  `store-assets/creative/art/`.
- **Recitation filters**: some prompts/models return `finish_reason: content_filter`
  (`IMAGE_RECITATION`); keep prompts abstract ("paper texture, no logos/text") and
  retry or switch model.
- **No video models** in the catalog — animate by rendering frames and piping raw
  RGB to `ffmpeg` (`libx264`, `yuv420p`, `-crf 16`, `+faststart`).
- **Agent loop**: `opencode run -m <provider/model> --format json --auto "<brief>"`
  can edit the YAML and re-render; it cannot emit raster art itself.

## Porting to another app

1. Copy the four scripts (they are app-agnostic) and `scripts/asc/` from that app.
2. Standardise the app id: add `APP_ID = <APP>_APP_ID` to
   `scripts/asc/constants.py` and have the scripts import `APP_ID` — the same
   files then work in every app repo.
3. Rasterize the app mark:
   `inkscape AppIcon.icon/Assets/<mark>.svg --export-type=png --export-area-drawing --export-width=2000`.
   Multi-layer icons (several SVGs in the `.icon` bundle) need one combined SVG
   first; bump weak layers' opacity so the mark is visible at background scale.
4. Create `store-assets/creative/<app>.yaml`: app id/name, palette from the app,
   wordmark + two-line headline per placement, `ui.shot` pointing at a real
   portrait capture, durations, motif ratios. The renderer resolves
   `store-assets/creative/<repo-name>.yaml` by default.
5. Iterate with `--format still --preview`; check the motif style if unsure.
6. Render videos, upload with `--no-place`, submit for review, then place by id
   (live app) or upload with `--replace` (version in review).
7. Add the commands to the app's release runbook.

**One family, several apps:** sibling apps from the same studio should share the
backdrop palette, type scale, and motion recipe — only the wordmark, headline,
motif, and UI card change. That makes the App Store pages look like one brand.
