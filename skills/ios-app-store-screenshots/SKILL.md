---
name: ios-app-store-screenshots
description: >-
  Capture, compose, and upload iOS App Store screenshots via UI tests, xcresult
  export, Pillow marketing frames with named compositions, and the App Store
  Connect API. Use when the user asks to generate store screenshots, refresh App
  Store screenshots, explore composition variants, run capture-screenshots.sh /
  compose_store_assets.py / upload_store_assets.py, fix DemoMode or Ask/search
  screenshot fixtures, or submit screenshot sets to ASC — not for the full
  release/tag/TestFlight ship (use ios-app-store-release for that).
---
# iOS App Store Screenshots

Screenshot-only pipeline for apps that already have ASC release scripts (Gregor/Melvil pattern). For end-to-end ship (bump, Cloud archive, metadata, submit), use [ios-app-store-release](../ios-app-store-release/SKILL.md).

## Expected repo layout

```
store-assets/
  scenes.yaml                 # scene → composition, template, headline, raw, upload
  compositions.yaml           # named layouts (rising, hero-low, from-right, …)
  templates/{light,dark}.json # colors, device/text shadow chrome
  raw/<device>/…png           # simulator captures
  composed/<DISPLAY_TYPE>/…   # locked marketing frames + manifest.json
  composed/explore/…          # optional contact sheet while iterating
scripts/
  capture-screenshots.sh
  export_xcresult_screenshots.py
  compose_store_assets.py
  upload_store_assets.py
  asc/{client,constants,screenshots,metadata}.py
Tests/<App>UITests/ScreenshotTests.swift
Sources/…/Demo/DemoMode.swift   # DEBUG-only fixture vault + screenshotScene
```

Credentials: `~/.config/app-store-connect/credentials.json`. Deps: `pip install -r scripts/requirements-asc.txt`.

## Agent workflow

Copy and track:

```
- [ ] Confirm APP_ID + version exists (PREPARE_FOR_SUBMISSION or editable)
- [ ] Confirm DemoMode + ScreenshotTests cover each scene in scenes.yaml
- [ ] Capture raw PNGs (light + dark as needed)
- [ ] Visually spot-check raw shots (no keyboard, correct screen, real content)
- [ ] Explore compositions if layouts are unsettled (--explore + contact sheet)
- [ ] Lock composition: + headlines in scenes.yaml; compose locked set
- [ ] Upload to ASC for marketing version
- [ ] Verify assetDeliveryState COMPLETE via API
```

### 1. Capture

Pin simulator name in the capture script (names drift with Xcode). Typical invocation:

```bash
./scripts/capture-screenshots.sh "iPhone 17 Pro Max" light collections
./scripts/capture-screenshots.sh "iPhone 17 Pro Max" dark collections
```

Argument order is **device → appearance → scene**. Swapping appearance/scene fails with a confusing error.

Inside the script:

1. `xcodegen generate` if the project is spec-driven
2. `xcodebuild test -resultBundlePath build/screenshot-<basename>.xcresult -only-testing:…/ScreenshotTests/test…`
3. `python3 scripts/export_xcresult_screenshots.py <xcresult> store-assets/raw/iphone`

**Do not** rely on `xcodebuild` shell env for `launchArguments`/`launchEnvironment` reaching the UI test host reliably. Persist via:

- XCTest `XCTAttachment` (lifetime `.keepAlways`) **and**
- writing PNG under `STORE_ASSET_DIR` from the test
- export script honoring `SCREENSHOT_BASENAME` (attachment suggested names include UUIDs)

Orchestrator pattern (all scenes) — keep in sync with `capture-screenshots.sh` / `release.py`:

```python
for scene in ("collections", "collection-lists", "list-editor", "search-ask"):
    for appearance in ("light", "dark"):
        run(["./scripts/capture-screenshots.sh", DEVICE, appearance, scene])
```

If a UI test hangs (~600s “Failure collecting diagnostics from simulator”), shut down sims, re-boot the pinned device, and retry that scene only:

```bash
xcrun simctl shutdown all
xcrun simctl boot "<UDID-or-name>"
```

**Iterate compose without re-capturing.** Raw PNGs are expensive; composition + headline tweaks are cheap.

### 2. Demo / fixture rules

Store shots need rich content; **App Store builds must not**.

- Gate seeding with `#if DEBUG` + launch arg (e.g. `-UITestDemo`) / env (`*_UI_TEST_DEMO=1`)
- Never ship bundled sample markdown via Release target membership or symlinks
- Review notes describe real first launch, not DemoMode fixtures
- Prefer `accessibilityIdentifier` on navigation targets; label `CONTAINS` predicates are fragile
- Marketing shots: **dismiss keyboard** before capture (tap results list / toolbar, or skip auto-focus when `DemoMode.isEnabled`)

#### Search / Ask demo screenshots

Ask screens need deterministic content — do **not** wait on live Foundation Models / Spotlight in UI tests.

Pattern (Gregor `NoteStore+Search` / Melvil `ListStore+Search`):

1. `DemoMode.screenshotScene` from `-UITestScene` / `SCREENSHOT_SCENE`
2. When scene is `search-ask`: set `forceAskMode`, `demoQuery`, `demoSummary` and/or `demoAnswer`, `demoResults` on the search context
3. Search view applies seeds in `.task` / `onAppear` (`applyDemoSeedIfNeeded`)
4. UITest opens search via `*.search` accessibility id, waits for Ask chrome / Answer section, dismisses keyboard, then captures

Seed answers/snippets from the **demo vault** (e.g. Japan trip packing gaps) so the shot looks real.

### 3. Compose

Locked set (upload path):

```bash
python3 scripts/compose_store_assets.py
```

Explore variants (iteration):

```bash
python3 scripts/compose_store_assets.py --explore --scene collections-light
# optional: --composition rising-leading --composition hero-low-leading
```

Writes `composed/explore/<scene>__<composition>.png` plus `contact-sheet.png`. Default compose **requires** `composition:` on each scene.

App Store upload set convention (Gregor/Melvil):

- Upload **all light** scenes in story order
- Upload **one** dark home/hero shot
- Mark remaining dark variants `upload: false` (still compose for local review)

Composition schema, text placement, and chrome rules: [references/compositions.md](references/compositions.md).

### 4. Copy (headlines)

- **One title only** — no faded subheads; put the whole message in `headline`
- **Manual line breaks** via YAML `|` — compose must **not** auto-reflow (avoids orphans/widows)
- Prefer short, quirky, app-specific lines over generic marketing speak
- Offer the user **multiple options** for unsettled scenes; lock picks in `scenes.yaml` before ship

### 5. Upload

```bash
python3 scripts/upload_store_assets.py --version 1.0
# optional: --dry-run
```

Upload **replaces** the existing screenshot set for that display type (delete-all then re-upload). Pixel size must match `DISPLAY_SIZES` in `scripts/asc/constants.py` (e.g. `APP_IPHONE_67` → 1290×2796) or ASC/client validation fails.

Via full release orchestrator when `refresh_assets: true` in `releases/<ver>.yaml`: capture → compose → upload as the `assets` step.

### 6. Verify

```python
# After upload: each appScreenshots item should report COMPLETE
GET /appScreenshotSets/{id}/appScreenshots
→ attributes.assetDeliveryState.state == "COMPLETE"
```

Invalid `screenshotDisplayType` enums fail at set creation — see [references/traps.md](references/traps.md).

## Hard-won rules

- **Attachments + file write**, not hope that xcodebuild env propagates into the test runner
- **Honor `SCREENSHOT_BASENAME`** when renaming exported attachments
- **No keyboard** on marketing list/editor/Ask shots
- **DemoMode is DEBUG-only**; production stays empty / real bootstrap
- **Pin simulator names**; update when Xcode renames devices
- **Upload order** comes from composed manifest order; filename prefix `01-…`, `02-…` is cosmetic for ASC
- **Capture once, compose many** — explore compositions before re-running UITests
- **Shadows rotate with tilted devices** (build shadow in local space, then rotate with the shot)
- **Prefer solid template backgrounds** for marketing frames; patterned full-bleed art often loses to clean color fields (keep `backgroundImage` optional)
- Screenshot-only work stops after COMPLETE verification — do not bump versions or tag unless asked

## Related

- Full ship: [ios-app-store-release](../ios-app-store-release/SKILL.md)
- Compositions / text layout: [references/compositions.md](references/compositions.md)
- Display-type / API traps: [references/traps.md](references/traps.md)
