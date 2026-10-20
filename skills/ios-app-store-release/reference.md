# iOS App Store Release — Reference

## Credentials file

`~/.config/app-store-connect/credentials.json`:

```json
{
  "issuer_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "key_id": "XXXXXXXXXX",
  "private_key_path": "~/.config/app-store-connect/AuthKey_XXXXXXXXXX.p8",
  "team_id": "XXXXXXXXXX"
}
```

JWT: ES256, `aud: appstoreconnect-v1`, ~20 min expiry.

## ASC API traps

### First release `whatsNew`

`PATCH /appStoreVersionLocalizations/{id}` with `whatsNew` returns **409 STATE_ERROR** ("cannot be edited at this time") on version 1.0. Retry PATCH without `whatsNew`; other fields still apply.

### Build version vs marketing version

```http
GET /v1/builds?filter[app]={APP_ID}&include=preReleaseVersion&sort=-uploadedDate
```

| Field | Meaning |
|-------|---------|
| `data[].attributes.version` | Build number (`3`) |
| `included[type=preReleaseVersions].attributes.version` | Marketing version (`1.0`) |

### Build numbers must clear Xcode Cloud auto-numbering

Xcode Cloud auto-numbers builds (project `CURRENT_PROJECT_VERSION` may stay at `1` while ASC builds read `17`). A local `xcodegen` bump from the project value can therefore upload a build number **lower** than existing builds. Before a local archive, set the build number to `max(local, highest ASC build + 1)` — or a clearly higher value.

**Do not use that project build number as a `min_build_number` filter when selecting the build to attach.** Xcode Cloud may stamp its own CI run number (e.g. 28) while `project.yml` says 101, so a project-number floor rejects the real release build. Use `newer_than_build_id=<id of the previous eligible build>` instead.

### Select only App Store-eligible builds

A branch push also triggers the Beta workflow, whose builds are `INTERNAL_ONLY` (TestFlight-only). They are usually the newest builds, so an unfiltered “latest VALID build” picks the wrong one and the attach fails with `409 ENTITY_ERROR.RELATIONSHIP.INVALID`. Filter inside the selector:

```python
if build["attributes"].get("buildAudienceType") != "APP_STORE_ELIGIBLE":
    continue
```

Keep the contract explicit: `Release` workflow on tag `v*` = `APP_STORE_ELIGIBLE`; `Beta` workflow on `main` = `INTERNAL_ONLY`. If Beta were App Store-eligible, a FeedbackLoop build could be submitted.

### Screenshot display types

Invalid enums fail at upload time. Common valid values (verify in ASC for your SDK era):

| Device | Display type | Composed size |
|--------|--------------|---------------|
| iPhone 6.7" | `APP_IPHONE_67` | 1290 × 2796 |
| iPad Pro 12.9" (3rd gen) | `APP_IPAD_PRO_3GEN_129` | 2064 × 2752 |
| iPhone Duo (iOS 27.1 era) | `APP_IPHONE_DUO` | outer 1398 × 2034, inner 2007 × 2853 |

`APP_IPHONE_69` was rejected in practice — do not assume newer names work without checking.

### iPhone Duo screenshots (iOS 27.1 SDK era)

- ASC accepts `APP_IPHONE_DUO` via the API (verified) even while the public docs' enum list
  lags behind. One set takes both outer and inner sizes; 1–10 images, no alpha.
  Accepted sizes are exact: inner 2007 × 2853 / 2853 × 2007, outer 1398 × 2034 / 2034 × 1398 —
  compose frames onto the exact canvas (raw captures can come out 2006 × 2852 / 2852 × 2006).
- Required for apps submitted from April 2027 when built with the iOS 27.1 SDK (Apple has
  also said "any app submitted" — plan for the stricter reading).
- Prerequisites: Xcode 27.1 components installed (admin GUI first launch; an older
  CoreSimulator makes `simctl` hang), the iOS 27.1 simulator runtime
  (`xcodebuild -downloadPlatform iOS -buildVersion 27.1`, ~8 GB), and RocketSim for poses.
  The Duo device type is **incompatible with older runtimes** (`simctl create` fails with
  "Incompatible device"). Simulator.app is gone in Xcode 27; Device Hub replaces it.
- Capture notes that cost real time:
  - The inner display is **landscape-native**; portrait-only apps still render landscape
    there (27.1 SDK moves toolbar buttons into a vertical bar). Capture landscape.
  - `XCUIScreen` exports the inner drawable as a portrait-shaped PNG **rotated 90° CW** —
    normalize with `sips -r 90` (or capture the display directly from the host:
    `simctl io <udid> enumerate` lists screen IDs; `simctl io <udid> screenshot --display <id>`
    grabs a specific one). `XCUIScreen.screens` can list multiple displays — pick the largest.
  - `rocketsim duo pose open|book|closed --udid <udid>` applies even when
    `rocketsim duo hinge` keeps reporting `hinge_not_ready` (headless); treat the hinge read
    as advisory. RocketSim.app must be running for its CLI IPC.
- Live apps (`READY_FOR_SALE`) can only get new screenshots via a metadata-only update
  (review, no new build) or their next version; an older-SDK build won't be Duo-optimized.

### Creative assets (header + search results)

Product page header and search-results artwork are **not** screenshots — see
[ios-app-store-creative-assets](../ios-app-store-creative-assets/SKILL.md) for the
Asset Library API flow, generation pipeline, and design/motion recipe.

### App availability (non-preorder) is UI-only

`POST /v2/appAvailabilities` is documented as "Create an app pre-order" and rejects normal
availability payloads. For a normal all-territories availability use the ASC UI: Pricing
and Availability → Set Up Availability → all countries → Save. Check with
`GET /apps/{id}/appAvailabilityV2` (404 = not set).

### Age rating via API

```http
GET  /v1/appInfos/{infoId}/ageRatingDeclaration
PATCH /v1/ageRatingDeclarations/{declarationId}
```

Mirror a shipped sibling app's attribute values (booleans + enums like `"NONE"`); only
PATCH fields that differ. Works for the first submission.

### Review detail required fields

POST/PATCH `appStoreReviewDetails` requires:

- `contactFirstName`, `contactLastName`
- `contactPhone` — E.164 (`+5511976600011`)
- `contactEmail`
- `notes`
- `demoAccountRequired` — defaults to **true** on create; PATCH `false` for no-account apps

Copy from an existing app in the same team if starting fresh.

### Metadata lives on different resources

| Field | Resource |
|-------|----------|
| description, keywords, supportUrl, whatsNew | `appStoreVersionLocalizations` |
| subtitle, privacyPolicyUrl | `appInfoLocalizations` |
| copyright | `appStoreVersions` |
| contentRightsDeclaration | `apps` (`DOES_NOT_USE_THIRD_PARTY_CONTENT` or `USES_THIRD_PARTY_CONTENT`) |
| usesNonExemptEncryption | `builds` (PATCH) |

### Merge, do not overwrite (mandatory)

Before **any** PATCH of listing or review fields, GET the live ASC attributes and merge with local YAML / `review-notes.txt`. ASC is often richer than the repo (hand-edited reviewer notes, keywords, description).

- Prefer non-empty over empty; prefer longer text when both exist.
- On equal length with different text, keep ASC and write back to the repo.
- Keywords: union unique comma-separated tokens (ASC first), cap at 100 characters.
- Write winners back to `store-assets/metadata/` so hand edits survive the next ship.

Never treat “local non-empty” as license to clobber a richer ASC value (reviewer notes, keywords, description, contact). A short local `review-notes.txt` must not replace multi-section ASC notes.

### Do not cancel App Review to unblock shipping

`DELETE /appStoreVersionSubmissions` (Cancel Review) **restarts the review clock**. Never do this to create `1.x+1`, rename a version, or attach a newer build unless the human explicitly ordered cancel/withdraw in the current conversation.

If `POST /appStoreVersions` returns **409** (“You cannot create a new version… in the current state”), an earlier version is still unreleased / in queue — re-run **version selection** (SKILL.md): reuse an editable `PREPARE_FOR_SUBMISSION` version when present; if the blocker is already in review, upload the binary only and warn — do not withdraw.

### Submit for review via API

`POST /appStoreVersionSubmissions` now returns **403** for API keys:
`The resource 'appStoreVersionSubmissions' does not allow 'CREATE'. Allowed operation is: DELETE`.
Use the modern review-submission flow instead:

1. `POST /v1/reviewSubmissions` with `{platform: "IOS", app}`.
2. `POST /v1/reviewSubmissionItems` with `reviewSubmission` + `appStoreVersion`.
3. `PATCH /v1/reviewSubmissions/{id}` with `{submitted: true}`.

An existing `WAITING_FOR_REVIEW` submission may contain only creative assets. Check
`GET /reviewSubmissions/{id}/items?include=appStoreVersion` for the version id before
reusing or skipping; multiple submissions can coexist. Readiness failures surface as a
generic `409 STATE_ERROR.ENTITY_STATE_INVALID`; inspect `meta.associatedErrors`. A new
required declaration is
`STATE_ERROR.CANNOT_SUBMIT_MISSING_REGULATED_MEDICAL_DEVICE_APP_DECLARATION`: declare
**No** in App Store Connect → App Information → **Declare Regulated Medical Device**
(UI-only; applies to Health & Fitness/Medical categories). App Privacy remains UI-only too.

### Xcode Cloud CI product visibility

`GET /v1/ciProducts` may list only older products immediately after creating a workflow. Fallback: poll `GET /v1/builds?filter[app]=...` after tag push. SCM repo connection (`GET /v1/scmRepositories`) can exist before CI product appears in list API.

**Build-run workflow filter trap:** `GET /v1/ciProducts/{id}/buildRuns` omits the `workflow` relationship unless you pass `include=workflow`. A `wait_for_build_run(workflow_id=...)` that reads `relationships.workflow` without the include silently matches nothing and times out. Fetch `limit=50&include=workflow`, filter in Python, and pick the highest `number`.

### Create or update a Release workflow via API

`POST /v1/ciWorkflows` works. Required attributes: `name`, `description`, `isEnabled`,
`clean`, `containerFilePath`, `actions`; required relationships: `product`, `repository`,
`xcodeVersion` (id of `ciXcodeVersions` “Latest Release”), `macOsVersion` (id of
`ciMacOsVersions` “Latest Release”). Archive action needs
`buildDistributionAudience: "APP_STORE_ELIGIBLE"`. Add `tagStartCondition` with pattern
`v` + `isPrefix: true`; `manualBranchStartCondition` on `main` is useful for re-running a
release without minting a tag.

**PATCH replaces omitted start conditions.** Sending only
`manualBranchStartCondition` clears `tagStartCondition` and `manualTagStartCondition`.
Send all desired conditions in the same PATCH, then run the workflow audit.

### Agreement errors

403 with `REQUIRED_AGREEMENTS` — human must accept agreements in ASC.

## Screenshot upload flow (API)

1. `GET /apps/{id}/appStoreVersions` → find version id
2. `GET /appStoreVersions/{vid}/appStoreVersionLocalizations` → localization id
3. `POST /appScreenshotSets` with `screenshotDisplayType`
4. Delete existing screenshots in set if replacing
5. `POST /appScreenshots` → receive upload operations → PUT bytes to presigned URL
6. Poll until `assetDeliveryState.state == COMPLETE`

Use `include=appScreenshots` when verifying; relationship `data` may be empty without include even when screenshots exist.

## xcresult attachment export

`scripts/export_xcresult_screenshots.py` pattern:

- `xcrun xcresulttool export attachments --path … --output-path …`
- Parse `manifest.json` → copy PNGs
- Prefer `SCREENSHOT_BASENAME` env over attachment suggested name (iPad runs may still suggest iPhone names)

## Release state resume

Step order:

```
validate → tests → bump → commit → tag → wait-build → assets → asc-sync → submit → done
```

`should_skip(step)`: skip when `order.index(step) < order.index(state["step"])`. Use **strict less-than** so a failed step (state saved at step start) re-runs on `--resume`.

Write state **after** step success if you want stronger guarantees; at minimum fix off-by-one skip logic.

## ExportOptions.plist (local upload)

```xml
<key>method</key>
<string>app-store-connect</string>
<key>destination</key>
<string>upload</string>
<key>signingStyle</key>
<string>automatic</string>
```

Team ID in plist or rely on `-allowProvisioningUpdates`.

## store-assets/metadata/en-US.yaml template

```yaml
locale: en-US
supportUrl: https://example.github.io/app-legal/support/
privacyPolicyUrl: https://example.github.io/app-legal/privacy/
subtitle: Short subtitle
keywords: word1,word2,word3
copyright: "© 2026 Author"
contentRightsDeclaration: DOES_NOT_USE_THIRD_PARTY_CONTENT
reviewContact:
  firstName: First
  lastName: Last
  phone: "+1234567890"
  email: support@example.com
description: |
  ...
# Empty description pulls the live ASC listing into the repo on sync (merge policy).
# Prefer keeping the fuller of ASC vs local — never wipe hand-edited ASC copy.
# whats_new optional here; manifest.whats_new takes precedence as the local candidate
```

## review-notes.txt template (first submissions)

Reviewers consistently request the same info for new apps. Lead with a one-line testing
walkthrough, then answer the standing questions — the same list is reused across sibling
apps with app-specific answers (Gregor/Melvil/Sandow all shipped this way):

```
This is a simple app and testing it is straightforward: <shortest path through the main flow>. Thank you for reviewing my app!

Additional info requested for my other app, but could be relevant here:

1. A screen recording captured on a physical device:
Screen recording is attached!        # attach in ASC Review Notes UI; drop the line if not attaching

2. A list of the device models and operating systems the app was tested on:
iPhone <model> running iOS <version>
iPhone <model> running iOS <beta>

3. A description of the app's purpose and target audience:
The purpose of the app is to help users <core job> while owning their data in the form of reliable markdown files. The problems it solves are: <status quo problems — proprietary formats, accounts/subscriptions, data loss risk>. {App} addresses this and adds value by:
- Providing a polished native UI for <core job> (instead of writing markdown files directly);
- Storing data as plain markdown files that will continue to be reliable regardless of the longevity of the app;
- <any other differentiator: on-device AI, backups, dark mode…>.
The app targets <audience>.

4. Instructions for setting up and accessing the app's main features:
All that is necessary to use the app is to open it, <main flow steps>. <Where the markdown files live — app's iCloud folder if enabled, or the device via the Files app.> No log-in or credentials are needed.

5. A list of the external services, tools, or platforms the app uses to deliver its core functionality:
None! Everything is done locally using native iOS APIs. <Mention on-device Foundation Models conversions as local, if present.>

6. Describe any regional differences in the app's features or content, or confirm that the app functions consistently across all regions:
There are no regional differences. The app works exactly the same in all regions.

7. If the app operates in a highly regulated industry or includes protected third-party material:
It doesn't!
```

Describe **production** behavior only (empty first launch), never screenshot fixtures.

## Legal pages pattern (private app repo)

1. Canonical markdown in private repo: `legal/privacy.md`, `legal/support.md`
2. Public repo `{user}/{app}-legal` with GitHub Pages from `/docs`
3. Script renders MD → HTML and pushes to public repo
4. ASC `privacyPolicyUrl` + `supportUrl` point to Pages URLs

## DemoMode pattern (DEBUG-only)

```swift
enum DemoMode {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-UITestDemo")
        #else
        false
        #endif
    }
    // vaultLocationIfNeeded(), fixedDay — all #if DEBUG
}
```

`@main` app: use demo vault only when `DemoMode.isEnabled`; otherwise default `NoteStore()`.

## Unicode repo paths

Resolve manifest paths with `.resolve()` against repo root — avoid cwd-relative paths on macOS NFD vs NFC normalization.

## Readiness poll script (sketch)

Verify before telling user to Submit:

- Version state `PREPARE_FOR_SUBMISSION`
- Build relationship non-null
- Screenshot sets complete per display type
- `usesNonExemptEncryption == false`
- Review detail populated
- `contentRightsDeclaration` set on app
- `privacyPolicyUrl` on app info localization

## Orchestrator flags

| Manifest flag | Behavior |
|---------------|----------|
| `refresh_assets: true` | capture + compose + upload screenshots |
| `refresh_assets: false` | skip screenshot pipeline |
| `submit_for_review: false` | stop after asc-sync |
| `submit_for_review: true` | call submit API (if permitted) |
