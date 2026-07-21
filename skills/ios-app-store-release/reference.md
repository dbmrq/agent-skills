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

### Screenshot display types

Invalid enums fail at upload time. Common valid values (verify in ASC for your SDK era):

| Device | Display type | Composed size |
|--------|--------------|---------------|
| iPhone 6.7" | `APP_IPHONE_67` | 1290 × 2796 |
| iPad Pro 12.9" (3rd gen) | `APP_IPAD_PRO_3GEN_129` | 2064 × 2752 |

`APP_IPHONE_69` was rejected in practice — do not assume newer names work without checking.

### Review detail required fields

POST/PATCH `appStoreReviewDetails` requires:

- `contactFirstName`, `contactLastName`
- `contactPhone` — E.164 (`+5511976600011`)
- `contactEmail`
- `notes`

Copy from an existing app in the same team if starting fresh.

### Metadata lives on different resources

| Field | Resource |
|-------|----------|
| description, keywords, supportUrl, whatsNew | `appStoreVersionLocalizations` |
| subtitle, privacyPolicyUrl | `appInfoLocalizations` |
| copyright | `appStoreVersions` |
| contentRightsDeclaration | `apps` (`DOES_NOT_USE_THIRD_PARTY_CONTENT` or `USES_THIRD_PARTY_CONTENT`) |
| usesNonExemptEncryption | `builds` (PATCH) |

### Merge, do not overwrite

Before PATCH, GET the live ASC attributes and merge with local YAML / `review-notes.txt`:

- Prefer non-empty over empty; prefer longer text when both exist.
- On equal length with different text, keep ASC and write back to the repo.
- Keywords: union unique comma-separated tokens (ASC first), cap at 100 characters.
- Write winners back to `store-assets/metadata/` so hand edits survive the next ship.

Never treat “local non-empty” as license to clobber a richer ASC value (reviewer notes, keywords, description, contact).

### Submit for review via API

`POST /appStoreVersionSubmissions` may return **403** (`CREATE` not allowed for API key role). Treat API submit as optional; human Submit in ASC is reliable.

### Xcode Cloud CI product visibility

`GET /v1/ciProducts` may list only older products immediately after creating a workflow. Fallback: poll `GET /v1/builds?filter[app]=...` after tag push. SCM repo connection (`GET /v1/scmRepositories`) can exist before CI product appears in list API.

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

## review-notes.txt template

Describe **production** behavior only:

```
{App} is a … app. Notes are stored as …

No login is required. On first launch the app starts with an empty journal.

Optional features: …

Contact: support@example.com
```

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
