---
name: ios-app-store-screenshots
description: >-
  Capture, compose, and upload iOS App Store screenshots via UI tests, xcresult
  export, Pillow marketing frames, and the App Store Connect API. Use when the
  user asks to generate store screenshots, refresh App Store screenshots, run
  capture-screenshots.sh / compose_store_assets.py / upload_store_assets.py,
  fix DemoMode screenshot fixtures, or submit screenshot sets to ASC — not for
  the full release/tag/TestFlight ship (use ios-app-store-release for that).
---

# iOS App Store Screenshots

Screenshot-only pipeline for apps that already have ASC release scripts (Gregor/Melvil pattern). For end-to-end ship (bump, Cloud archive, metadata, submit), use [ios-app-store-release](../ios-app-store-release/SKILL.md).

## Expected repo layout

```
store-assets/
  scenes.yaml                 # scene → template, displayType, raw path, upload flag
  templates/{light,dark}.json
  raw/<device>/…png           # simulator captures
  composed/<DISPLAY_TYPE>/…   # marketing frames + manifest.json
scripts/
  capture-screenshots.sh
  export_xcresult_screenshots.py
  compose_store_assets.py
  upload_store_assets.py
  asc/{client,constants,screenshots,metadata}.py
Tests/<App>UITests/ScreenshotTests.swift
Sources/…/Demo/DemoMode.swift   # DEBUG-only fixture vault
```

Credentials: `~/.config/app-store-connect/credentials.json`. Deps: `pip install -r scripts/requirements-asc.txt`.

## Agent workflow

Copy and track:

```
- [ ] Confirm APP_ID + version exists (PREPARE_FOR_SUBMISSION or editable)
- [ ] Confirm DemoMode + ScreenshotTests cover each scene in scenes.yaml
- [ ] Capture raw PNGs (light + dark as needed)
- [ ] Visually spot-check raw shots (no keyboard, correct screen, real content)
- [ ] Compose marketing frames
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

Orchestrator pattern (all scenes):

```python
for scene in ("collections", "collection-lists", "list-editor"):
    for appearance in ("light", "dark"):
        run(["./scripts/capture-screenshots.sh", DEVICE, appearance, scene])
```

If a UI test hangs (~600s “Failure collecting diagnostics from simulator”), shut down sims, re-boot the pinned device, and retry that scene only:

```bash
xcrun simctl shutdown all
xcrun simctl boot "<UDID-or-name>"
```

### 2. Demo / fixture rules

Store shots need rich content; **App Store builds must not**.

- Gate seeding with `#if DEBUG` + launch arg (e.g. `-UITestDemo`) / env (`*_UI_TEST_DEMO=1`)
- Never ship bundled sample markdown via Release target membership or symlinks
- Review notes describe real first launch, not DemoMode fixtures
- Prefer `accessibilityIdentifier` on navigation targets; label `CONTAINS` predicates are fragile
- Marketing shots: **dismiss keyboard** before capture (tap toolbar `Done`, or skip auto-focus when `DemoMode.isEnabled`)

### 3. Compose

```bash
python3 scripts/compose_store_assets.py
```

Reads `store-assets/scenes.yaml` + templates; writes `composed/<DISPLAY_TYPE>/` and `composed/manifest.json`.

App Store upload set convention (Gregor/Melvil):

- Upload **all light** scenes in story order
- Upload **one** dark home/hero shot
- Mark remaining dark variants `upload: false` (still compose for local review)

### 4. Upload

```bash
python3 scripts/upload_store_assets.py --version 1.0
# optional: --dry-run
```

Upload **replaces** the existing screenshot set for that display type (delete-all then re-upload). Pixel size must match `DISPLAY_SIZES` in `scripts/asc/constants.py` (e.g. `APP_IPHONE_67` → 1290×2796) or ASC/client validation fails.

Via full release orchestrator when `refresh_assets: true` in `releases/<ver>.yaml`: capture → compose → upload as the `assets` step.

### 5. Verify

```python
# After upload: each appScreenshots item should report COMPLETE
GET /appScreenshotSets/{id}/appScreenshots
→ attributes.assetDeliveryState.state == "COMPLETE"
```

Invalid `screenshotDisplayType` enums fail at set creation — see [references/traps.md](references/traps.md).

## Hard-won rules

- **Attachments + file write**, not hope that xcodebuild env propagates into the test runner
- **Honor `SCREENSHOT_BASENAME`** when renaming exported attachments
- **No keyboard** on marketing list/editor shots
- **DemoMode is DEBUG-only**; production stays empty / real bootstrap
- **Pin simulator names**; update when Xcode renames devices
- **Upload order** comes from composed manifest order; filename prefix `01-…`, `02-…` is cosmetic for ASC
- Screenshot-only work stops after COMPLETE verification — do not bump versions or tag unless asked

## Related

- Full ship: [ios-app-store-release](../ios-app-store-release/SKILL.md)
- Display-type / API traps: [references/traps.md](references/traps.md)
