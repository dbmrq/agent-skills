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

## Safe area: the canvas gets cropped

The App Store does **not** show the whole canvas. It crops per device and
orientation, so anything outside the centred band can disappear. Apple's own
creative-asset templates mark an "ART SAFE AREA" (measured from the Sketch
templates; Apple publishes no pixel numbers):

| Placement | Canvas | Safe area | Share of canvas |
|---|---|---|---|
| Product page header | 3840 × 1646 | 1646 × 661 centred | 43 % × 40 % |
| Search results | 3840 × 2560 | 2168 × 1030 centred | 56.5 % × 40.2 % |
| Universal | 5244 × 2950 | 1402 × 962 (334 px **above** centre) | 26.7 % × 32.6 % |

A device preview on a real iPhone showed less than the template promises: the
header kept only the **middle ~60 %** of its width (the visible slice started
at the "u" of "Your lists."). Treat the template numbers as the floor and a
measured crop as the working number.

**The two placements are cropped very differently — do not use one band for
both:**

- **Header** is the narrow 21:9 hero, and the App Store shows it as a much
  squarer band on an iPhone. Keep the lockup inside Apple's template band
  (43 % × 40 %). Apple's own examples centre it, and they carry no
  screenshot: the product page shows the real screenshots right below the
  header, so a screenshot in the header is redundant.
- **Search** is a dedicated 3:2 asset shown in a **3:2 card** at the full
  width of the search result — iPhone crops nothing. Apple's own search
  examples put the type at the left edge with the imagery bleeding off the
  right. The template's 56.5 % band is the conservative fallback for other
  orientations, not a reason to shrink the type.

The renderer enforces the band: `safeArea` in the YAML declares it per
placement and the text is laid out inside it.

```yaml
header:
  safeArea:
    widthRatio: 0.43      # centred horizontal band, fraction of the canvas
    heightRatio: 0.40     # centred vertical band for the text block
    insetRatio: 0
  card: false             # the product page shows the screenshots already
  textAlign: center
  headline: |
    Your lists.
    In plain markdown.

search:
  safeArea:
    widthRatio: 1.0       # a 3:2 asset in a 3:2 card: no crop
    heightRatio: 1.0
    insetRatio: 0.105     # the text margin
  cardRightRatio: 0.925   # the card bleeds towards the right edge
  columnGapRatio: 0.1
```

`--check` verifies the invariant (text inside the band, no text/card
overlap) and `--safe-area` tints the still outside it. Both are cheap — run
them before every render.

## The motif art must be a single mark

The motif is the app icon blown up to a soft background shape. Rasterize
**one recognisable mark**, not the whole icon bundle: an icon sheet (a task
list with a row, a check and a cross) turns into a pile of random shapes
behind the type. Cut a single shape into its own SVG and export that
(`inkscape mark.svg --export-type=png --export-area-drawing
--export-width=2000`).

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
# 0. verify the content stays inside the safe area (text + screenshot)
python3 scripts/creative_assets.py --check

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
- **Everything inside the safe area** — that is the whole layout budget. The
  wordmark and headline scale with the headline (`wordmarkScale`), the
  headline is shrunk until it fits the column between the band edge and the
  screenshot card. A ~10% inset is *not* enough for the header: the App
  Store crops it to the middle ~60 %, and Apple's template is stricter.
- **One real UI card in the search asset**, anchored right, **~25% cropped
  below the frame** so the interface reads large without shrinking the copy.
  Its *visible width* may bleed towards the edge (the 3:2 search card is not
  cropped); the vertical bleed is the intended crop. The **header** gets no
  card — the product page shows the screenshots right below it.
- **Motif**: rasterize the app icon (Inkscape) into a huge, soft middle layer.
  The **glass** treatment (translucent white fill + subtle top sheen, **no stroke**,
  faint lift shadow) reads best on a light background; increase fill opacity
  until it is clearly visible. `soft` reads like a shadow; `outline` is too faint.
  One recognisable mark only — see above. The motif is bleed: it may live
  outside the band, and it can be positioned per placement
  (`motif: { header: { centerXRatio: 0.5 } }`).
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
3. Rasterize **one** app mark:
   `inkscape AppIcon.icon/Assets/<mark>.svg --export-type=png --export-area-drawing --export-width=2000`.
   Multi-layer icons (several SVGs in the `.icon` bundle) need one combined SVG
   first; bump weak layers' opacity so the mark is visible at background scale.
   If the SVG is a sheet of several marks (a task list with a row, a check and a
   cross), cut a single shape into its own SVG — the motif is a background
   shape, and a sheet reads as random shapes.
4. Create `store-assets/creative/<app>.yaml`: app id/name, palette from the app,
   wordmark + two-line headline per placement, `safeArea` per placement (copy
   the sibling app's ratios so the family matches), `ui.shot` pointing at a
   real portrait capture, durations, motif ratios. The renderer resolves
   `store-assets/creative/<repo-name>.yaml` by default.
5. Iterate with `--format still --preview`; check the motif style if unsure.
   Run `--check` to prove the content sits inside the safe area.
6. Render videos, upload with `--no-place`, submit for review, then place by id
   (live app) or upload with `--replace` (version in review).
7. Add the commands to the app's release runbook.

**One family, several apps:** sibling apps from the same studio should share the
backdrop palette, type scale, safe-area ratios, and motion recipe — only the
wordmark, headline, motif, and UI card change. That makes the App Store pages
look like one brand.
