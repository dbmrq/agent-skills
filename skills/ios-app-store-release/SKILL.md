---
name: ios-app-store-release
description: >-
  Ship iOS apps to App Store Connect end-to-end — Xcode Cloud, ASC API metadata
  and screenshots, release manifests, TestFlight, and prepare-for-submission
  without auto-submit. Use when publishing an iOS app, setting up App Store
  automation, ASC API scripts, store screenshots, Xcode Cloud release workflows,
  or preparing a version for App Review.
---

# iOS App Store Release

Agent playbook for **repeatable, mostly-automated** iOS releases. Assumes Swift/SwiftUI, optional XcodeGen, Python ASC client, and Xcode Cloud for archives.

**Out of scope (agent already knows):** creating Apple Developer accounts, basic `xcodebuild`, writing App Store copy from scratch, generic git tagging.

## Before starting

Collect per-app constants (store in `scripts/asc/constants.py` or equivalent):

| Constant | Example | Notes |
|----------|---------|-------|
| `APP_ID` | ASC apps resource id | Not bundle id |
| `BUNDLE_ID` | `co.example.app` | |
| `DEFAULT_LOCALE` | `en-US` | |
| `CI_PRODUCT_NAME` | App name in Xcode Cloud | May lag in ASC API after first workflow setup |
| Screenshot display types | `APP_IPHONE_67`, `APP_IPAD_PRO_3GEN_129` | Validate against ASC — invalid enums fail upload |
| Composed pixel sizes | iPhone 1290×2796, iPad 2064×2752 | Must match display type |

Credentials: `~/.config/app-store-connect/credentials.json` with `issuer_id`, `key_id`, `private_key_path`, optional `team_id`.

```bash
pip install -r scripts/requirements-asc.txt   # PyJWT, requests, pyyaml, Pillow
```

## Target architecture (per app repo)

```
releases/<version>.yaml          # ship intent: version, whats_new, flags
store-assets/
  metadata/<locale>.yaml         # keywords, URLs, copyright, review contact
  metadata/review-notes.txt
  scenes.yaml                    # screenshot scenes → display type + raw path
  composed/                      # marketing frames (generated)
scripts/
  release.py                     # orchestrator: validate → test → bump → tag → wait → assets → asc-sync → submit
  asc/{client,metadata,builds,screenshots,submit}.py
  compose_store_assets.py
  upload_store_assets.py
  capture-screenshots.sh
  check_xcode_cloud.py
ci_scripts/
  ci_post_clone.sh               # brew xcodegen + generate (if spec-driven)
  ci_pre_xcodebuild.sh           # sanity check generated .xcodeproj exists
```

**Design choices that paid off:**

- **Tests local, archive in Cloud** — saves Cloud compute; only Release workflow on tag.
- **YAML manifest per release** — agents edit ship intent, not ASC UI.
- **`submit_for_review: false`** default for first ship — human presses Submit after visual check.
- **`.release-state.json` + `--resume`** — idempotent recovery; skip completed steps with strict `<` ordering (failed step must re-run).
- **Legal/support URLs** — separate **public** repo + GitHub Pages; app repo stays private.

Reference templates and API traps: [reference.md](reference.md).

## End-to-end ship workflow

Copy and track:

```
- [ ] ASC app record exists; version created (PREPARE_FOR_SUBMISSION)
- [ ] Legal pages live (privacy + support URLs reachable)
- [ ] Xcode Cloud Release workflow: correct *.xcodeproj path, tag trigger
- [ ] Demo/screenshot data isolated from Release builds (#if DEBUG)
- [ ] release manifest written
- [ ] Dry-run pipeline
- [ ] Ship (or resume)
- [ ] Verify readiness checklist
- [ ] Human: App Privacy questionnaire in ASC UI if Submit disabled
- [ ] Human: Submit for Review (unless auto-submit enabled)
```

### 1. Release manifest

```yaml
version: "1.0"
whats_new: |
  Initial release.
promotional_text: ""
refresh_assets: true
submit_for_review: false
```

`whats_new` required for validator even when ASC rejects it on **first release** (handle in metadata sync — see reference).

### 2. Orchestrator steps

Typical order:

1. **validate** — manifest + required metadata fields
2. **tests** — unit tests locally (`GregorTests`-style, not full UI suite)
3. **bump** — `MARKETING_VERSION` + increment `CURRENT_PROJECT_VERSION` in `project.yml`, run `xcodegen`
4. **commit + tag** — `v{version}`, push branch + tag (triggers Cloud)
5. **wait-build** — poll Xcode Cloud product **or** ASC builds API until `processingState: VALID`
6. **assets** (if `refresh_assets`) — capture → compose → upload screenshots
7. **asc-sync** — metadata, review detail, export compliance, attach build
8. **submit** (optional) — create submission; often blocked by API role or left to human

```bash
./scripts/ship.sh ship releases/1.0.yaml --dry-run
./scripts/ship.sh ship releases/1.0.yaml
./scripts/ship.sh ship releases/1.0.yaml --resume
./scripts/ship.sh status --version 1.0
```

### 3. Build wait fallback

If `find_ci_product()` returns nothing (common right after first workflow setup), poll ASC builds:

```python
GET /v1/builds?filter[app]={APP_ID}&include=preReleaseVersion&sort=-uploadedDate
```

**Trap:** `build.attributes.version` is the **build number** (e.g. `3`), not marketing version. Match via `included` `preReleaseVersions.attributes.version`.

Local archive fallback when Cloud is broken: `xcodebuild archive` → `exportArchive` → `xcrun altool --upload-app`. Copy `.p8` to `~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8` — altool ignores custom `--apiKeyPath` unless file is in that directory.

After upload, PATCH build: `usesNonExemptEncryption: false` (and set `ITSAppUsesNonExemptEncryption` = NO in Info.plist for future uploads).

## Screenshots (non-obvious)

**Do not** rely on `launchEnvironment`/`launchArguments` passed through `xcodebuild` shell env for UI tests — use **XCTest attachments** + export:

```bash
xcodebuild test -resultBundlePath build/screenshot.xcresult ...
xcrun xcresulttool export attachments --path build/screenshot.xcresult --output-path staging/
```

Honor `SCREENSHOT_BASENAME` when exporting (attachment suggested names may not match device).

Pipeline: raw simulator capture → `compose_store_assets.py` (Pillow + `scenes.yaml`) → `upload_store_assets.py --version X.Y`.

Register **`accessibilityIdentifier`** on key UI for stable UI tests.

Simulator names drift (`iPhone 17 Pro Max`, `iPad Pro 13-inch (M5)`) — pin in capture script, update when Xcode adds devices.

## Demo / mock data (critical)

Store screenshots need content; **App Store builds must not**.

- Gate all demo vault seeding behind `#if DEBUG` and launch args (e.g. `-UITestDemo`).
- Production: empty journal only (`JournalBootstrap.ensureDefaultJournal` — directories, no notes).
- **Review notes** must describe real first-launch behavior (empty journal), not screenshot fixtures.
- Never symlink or ship bundled sample markdown in the app target.

## Xcode Cloud

**`ci_post_clone.sh`:** install/run `xcodegen generate` when `.xcodeproj` is generated from spec.

**Workflow project path** must exactly match repo root project name (`Gregor.xcodeproj`). Renaming the project requires updating the workflow in **Xcode → Product → Xcode Cloud → Manage Workflows** — ASC stores `containerFilePath`; a stale name fails before CI scripts run. Do not commit symlinks for old names.

Confirm:

- Release workflow triggers on **tag** `v*`
- Scheme = app target, action = Archive, distribution = App Store
- `Gregor.xcodeproj/xcshareddata/xcodecloud/manifest.json` ids match after workflow creation (Xcode writes these)

Monitor: `scripts/check_xcode_cloud.py --product "{AppName}" --wait 1200`

## ASC sync checklist (API-verifiable)

After `asc-sync`, confirm:

| Check | API hint |
|-------|----------|
| Build attached | `appStoreVersions` → `build` relationship |
| Export compliance | `builds` → `usesNonExemptEncryption: false` |
| Screenshots | `appScreenshotSets` with `include=appScreenshots`; `assetDeliveryState.state: COMPLETE` |
| Support URL | version localization |
| Privacy policy URL | **appInfoLocalizations** (not version localization) |
| Copyright | `appStoreVersions` |
| Content rights | `apps.contentRightsDeclaration` |
| Age rating | `appInfos/.../ageRatingDeclaration` |
| Review contact | `appStoreReviewDetail` — first/last name, phone in E.164, email |

**Human-only in ASC UI:** App Privacy nutrition labels (no stable public API), paid agreements, tax/banking.

## Human gates (do not block automation on these)

- First GitHub ↔ Xcode Cloud connect
- App Privacy questionnaire
- Pressing **Submit for Review** (recommended even when API submit exists)
- App Review rejection iteration

## Porting to a new app

1. Create ASC app + version in UI (API cannot create apps).
2. Fill age rating, export compliance questionnaire once.
3. Wire constants, metadata YAML, release manifest.
4. Copy/adapt `scripts/asc/*` and orchestrator; rename product/scheme.
5. Add UI screenshot test + `DemoMode` (DEBUG-only).
6. Create Xcode Cloud Release workflow; verify project path.
7. First ship with `submit_for_review: false`; human verifies ASC listing then submits.

## Related skills

- [xcodegen](../xcodegen/SKILL.md) — spec-driven projects + Cloud post-clone
- [device-interaction](https://github.com/superagents-lab/xcode27-skills) — simulator verification (Apple toolchain export)
- [swiftui-expert-skill](https://github.com/avdlee/swiftui-agent-skill) — UI performance while building screenshot flows

## Additional resources

- ASC API traps, JSON bodies, file templates: [reference.md](reference.md)
