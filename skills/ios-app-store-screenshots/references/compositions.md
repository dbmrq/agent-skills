# Marketing compositions

Named layouts live in `store-assets/compositions.yaml`. Each scene in `scenes.yaml` sets `composition:` to one name. Templates (`templates/{light,dark}.json`) own colors and shadow chrome — not geometry.

## Iteration loop

1. Capture raw screenshots once.
2. `--explore` every composition (or a shortlist) for one scene → open `composed/explore/contact-sheet.png`.
3. Lock 3–5 keepers in `compositions.yaml`; assign per scene in `scenes.yaml`.
4. Tweak headlines / ratios; recompose only (no re-capture).
5. Default `compose_store_assets.py` builds the locked set for upload.

Vary **light vs dark templates** and **composition** across the upload story so consecutive shots do not look identical.

## Keeper set (Melvil reference)

| Name | Intent |
|------|--------|
| `rising-leading` | Text in empty band; large device rising from bottom-left, slight CW tilt, clipped |
| `from-right` | Leading text; device entering from the right, mild tilt, clipped |
| `hero-low-leading` | Leading text block; large untilted device low, bottom clipped |
| `leading-bottom` | Full device above; text centered in the lower empty band |

Reuse names across apps; swap only art/copy.

## Text model (align ≠ position)

| Key | Meaning |
|-----|---------|
| `align` | Line alignment **within** the content block (`leading` \| `center`) |
| `blockAlign` | Where the **content-tight** block sits in the horizontal region (`start` \| `center` \| `end`) |
| `verticalAlign` | Where the block sits in the **empty vertical band** (`start` \| `center` \| `end`) — default `center` |
| `regionXRatio` / `regionWidthRatio` | Horizontal band the block may occupy |
| `fitWidthRatio` | Narrower measure used to **size** type, then park the tight block in the region |
| `maxHeightRatio` | Optional cap on type size inside the band |
| `lineGapRatio` | Extra gap between lines as a fraction of point size (~0.6–0.7 reads airy) |

**Why `fitWidthRatio`:** long left-aligned lines that fill the region look “stuck left” or accidentally centered. Size against a narrower measure, then `blockAlign: center` so leading copy sits in the empty space without hugging the margin.

**Vertical band:** place the device first; the remaining empty strip (above a rising/hero shot, or below a bottom text layout) owns the headline. For tilted shots, compute the band against the **visual** top of the rotated rect, not the unrotated `yRatio`.

**Copy:** one `headline` with explicit `\n` / YAML `|` breaks. No subheads. Compose must not auto-wrap.

## Shot model

| Key | Meaning |
|-----|---------|
| `placement: absolute` | `xRatio` / `yRatio` top-left of unrotated shot; `allowClip: true` for rising/hero |
| `placement: afterText` | Classic card: device fills the non-text area |
| `widthRatio` | Device width vs canvas |
| `rotationDeg` | Degrees; shadow must be built in local space then rotated **with** the device |
| `gapAfterTextRatio` | Gap between text band and device |

Top-heavy app chrome (nav + short lists) benefits from `rising-*` / `hero-low-*` so empty list bottoms are cropped out of frame.

## Template chrome

```json
{
  "background": "#F2F2F7",
  "headlineColor": "#1C1C1E",
  "shadowBlur": 52,
  "shadowOffsetY": 28,
  "shadowOpacity": 0.22,
  "textShadowBlur": 36,
  "textShadowOffsetY": 16,
  "textShadowOpacity": 0.36,
  "outlineWidth": 0
}
```

- Device shadow: soft rounded rect under the shot; **rotate with the shot** when `rotationDeg ≠ 0`.
- Text shadow: blur the glyph alpha (slightly expanded), offset down, composite under the headline — same language as device chrome.
- Optional `backgroundImage`: cover-crop to display size. Prefer solid `background` unless patterned art clearly wins in review; Melvil reverted patterned fills in favor of solids.
- Dark screenshots on dark canvases can hide the device silhouette; prefer stronger device shadow over a hard outline unless the user asks for a bezel.

## scenes.yaml shape

```yaml
scenes:
  - id: collections-light
    headline: |
      File under:
      everything
    composition: rising-leading
    template: light
    displayType: APP_IPHONE_67
    raw: raw/iphone/collections-light.png
  - id: search-ask-light
    headline: |
      On-device brains
      for offline lists
    composition: rising-leading
    template: light
    displayType: APP_IPHONE_67
    raw: raw/iphone/search-ask-light.png
  - id: collections-dark
    headline: |
      Lights out.
      Lists on.
    composition: leading-bottom
    template: dark
    displayType: APP_IPHONE_67
    raw: raw/iphone/collections-dark.png
  - id: collection-lists-dark
    headline: |
      Same shelf.
      Different vibes.
    composition: from-right
    template: dark
    displayType: APP_IPHONE_67
    raw: raw/iphone/collection-lists-dark.png
    upload: false
```

Fonts: prefer SF Pro Display Bold from `/Library/Fonts/` when present (system `SFNS.ttf` alone is Regular).
