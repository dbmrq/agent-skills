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

## Hard rules (never violate)

These are **stop-and-ask** constraints. Convenience (unblocking `asc-sync`, bumping a marketing version, “fixing” a stuck ship) does **not** override them.

1. **Never blind-overwrite ASC listing or review data.** Live App Store Connect is the source of truth when it differs from the repo or from what an agent “remembers.” Always **GET** before PATCH; **merge** per [ASC metadata merge](#asc-metadata-merge-do-not-blind-overwrite); prefer ASC (or the richer side) for review notes, description, keywords, contact, etc. Local `review-notes.txt` / YAML being non-empty is **not** permission to replace a longer ASC value. After merge, **write winners back** into `store-assets/` so the next ship does not regress.

2. **Never remove a version from App Review** (no `DELETE /appStoreVersionSubmissions`, no “Cancel Review” / withdraw, no developer-reject-to-edit) unless the human **explicitly** asks in this conversation. Canceling **restarts the review clock** and can add days of wait. If ASC blocks creating `1.1` because `1.0` is `WAITING_FOR_REVIEW` / `IN_REVIEW` / `PENDING_APPLE_RELEASE`, **stop and ask** — do not cancel, rename, or replace the in-flight version to unblock automation.

3. **Do not invent a workaround that mutates an in-review version** (rename `1.0`→`1.1`, swap the attached build, rewrite notes) without explicit human approval. Prefer waiting for approval/release, or shipping the new binary only after the human decides how to handle the queue.

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

Deep capture / compose / ASC upload workflow: **[ios-app-store-screenshots](../ios-app-store-screenshots/SKILL.md)**.

Summary for ship pipelines: raw simulator capture → `compose_store_assets.py` (Pillow + `scenes.yaml`) → `upload_store_assets.py --version X.Y`. Use XCTest attachments + `SCREENSHOT_BASENAME` export (do not rely on `xcodebuild` shell env for launch args). Pin simulator names; gate DemoMode with `#if DEBUG`.

## Demo / mock data (critical)

Store screenshots need content; **App Store builds must not**.

- Gate all demo vault seeding behind `#if DEBUG` and launch args (e.g. `-UITestDemo`).
- Production: empty journal only (`JournalBootstrap.ensureDefaultJournal` — directories, no notes).
- **Review notes** must describe real first-launch behavior (empty journal), not screenshot fixtures.
- Never symlink or ship bundled sample markdown in the app target.

## Xcode Cloud

**`ci_post_clone.sh`:** install/run `xcodegen generate` when `.xcodeproj` is generated from spec.

**Private path dependencies** (e.g. sibling `../LeioMarkdown`): Xcode Cloud cannot `git clone` private HTTPS repos until access is granted. Failures look like `ci_post_clone.sh` exit **128**, then package resolve “path does not exist”.

**Manual fix (once):** App Store Connect → app → **Xcode Cloud → Settings → Repositories** (or the failed build’s **Grant Access** prompt) → grant the private dependency repo → re-run the workflow. Until then, use local archive upload.

**Do not brew-install SwiftLint or Periphery in Xcode Cloud CI scripts.** Cloud often gets an x86_64 SwiftLint bottle under Rosetta (`/usr/local`), which crashes loading `sourcekitdInProc` (SIGILL / exit 132). The Periphery Homebrew cask needs `sudo`, which Cloud does not allow — a failing `ci_post_xcodebuild.sh` fails the Archive even when compilation succeeded. If the app target has a Quality Check `preBuildScript`, skip it when `CI_XCODE_CLOUD` / `CI_PRIMARY_REPOSITORY_PATH` is set (same reason). Run format/lint/deadcode locally before tagging; keep Cloud scripts limited to checkout/project guards (or no-ops).

**Workflow project path** must exactly match repo root project name (`Gregor.xcodeproj`). Renaming the project requires updating the workflow in **Xcode → Product → Xcode Cloud → Manage Workflows** — ASC stores `containerFilePath`; a stale name fails before CI scripts run. Do not commit symlinks for old names.

Confirm:

- Release workflow triggers on **tag** `v*`
- Scheme = app target, action = Archive, distribution = App Store
- `Gregor.xcodeproj/xcshareddata/xcodecloud/manifest.json` ids match after workflow creation (Xcode writes these)

Monitor: `scripts/check_xcode_cloud.py --product "{AppName}" --wait 1200`

## ASC metadata merge (do not blind-overwrite)

**ASC may have been edited by hand (or by a prior ship) after the repo was last updated.** Treat every `asc-sync` as a merge against live data, not a push of local files.

`asc-sync` must **merge** repo YAML / review notes with live ASC values — never PATCH a field just because local is non-empty. Especially dangerous: shorter local `review-notes.txt` clobbering long reviewer instructions that only lived in ASC.

**Policy (most complete wins):**

| Situation | Action |
|-----------|--------|
| Only one side has text | Keep that side; write the other side up if needed |
| Both non-empty, different lengths | Keep the **longer** value |
| Same length, different text | Keep **ASC** (hand edits) and write back to repo |
| Keywords | **Union** unique tokens (ASC order first), max 100 chars; push/write if the union differs |

Applies to: description, keywords, support/marketing URLs, what’s new, promotional text, subtitle, privacy URL, copyright, **review notes**, review contact fields.

After merge, **write the winner back** into `store-assets/metadata/*.yaml` and `review-notes.txt` when ASC (or the union) was richer, so the next ship does not regress.

Empty local `description: ""` means “no local draft” — pull ASC into the repo rather than clearing ASC.

Log each field decision (`field: ASC more complete; writing back`, etc.) during sync.

If merge logic is missing in app scripts (e.g. review detail always PATCHes local notes), **fix the script** or GET+compare by hand before writing — do not run a clobbering sync “just this once.”

## Versions already in review

Before creating a new App Store version, attaching a build, or renaming `versionString`, check `appStoreState` / `appVersionState`.

| State | Agent action |
|-------|----------------|
| `WAITING_FOR_REVIEW`, `IN_REVIEW`, `PENDING_APPLE_RELEASE`, `PROCESSING_FOR_APP_STORE` | **Do not cancel.** Report the blocker; ask the human. |
| `PREPARE_FOR_SUBMISSION`, `DEVELOPER_REJECTED`, `REJECTED`, `METADATA_REJECTED` | Editable — sync/metadata/build attach OK with merge rules |
| `READY_FOR_SALE` | Safe to create the **next** marketing version |

“Cannot create a new version of the App in the current state” almost always means an unreleased version is still in the queue — **not** a cue to DELETE the submission.

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
- **Cancel Review / withdraw** — human-only; agents must not cancel to unblock a newer version (see [Hard rules](#hard-rules-never-violate))
- Choosing to replace an in-flight unreleased version’s build or marketing string

## Porting to a new app

1. Create ASC app + version in UI (API cannot create apps).
2. Fill age rating, export compliance questionnaire once.
3. Wire constants, metadata YAML, release manifest.
4. Copy/adapt `scripts/asc/*` and orchestrator; rename product/scheme.
5. Add UI screenshot test + `DemoMode` (DEBUG-only).
6. Create Xcode Cloud Release workflow; verify project path.
7. First ship with `submit_for_review: false`; human verifies ASC listing then submits.

## Related skills

- [ios-app-store-screenshots](../ios-app-store-screenshots/SKILL.md) — capture, compose, and upload store screenshots only
- [xcodegen](../xcodegen/SKILL.md) — deep XcodeGen traps for existing specs
- [ios-bootstrap](../ios-bootstrap/SKILL.md) — new app + quality gate scaffolding
- [device-interaction](https://github.com/superagents-lab/xcode27-skills) — simulator verification (Apple toolchain export)
- [swiftui-expert-skill](https://github.com/avdlee/swiftui-agent-skill) — UI performance while building screenshot flows

## Additional resources

- ASC API traps, JSON bodies, file templates: [reference.md](reference.md)
