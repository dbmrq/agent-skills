# App Store screenshot traps

## Display types and pixel sizes

Invalid `screenshotDisplayType` values fail when creating `appScreenshotSets`. Verify against ASC for the current API era; do not invent enums.

| Device | Display type | Composed size |
|--------|--------------|---------------|
| iPhone 6.7" | `APP_IPHONE_67` | 1290 × 2796 |
| iPad Pro 12.9" (3rd gen) | `APP_IPAD_PRO_3GEN_129` | 2064 × 2752 |

`APP_IPHONE_69` has been rejected in practice — check before using newer names.

Client-side size check (Pillow) before upload prevents cryptic ASC failures:

```python
DISPLAY_SIZES = {
    "APP_IPHONE_67": (1290, 2796),
}
```

## Upload API flow

1. Resolve `appStoreVersions` by marketing version string
2. Ensure `appStoreVersionLocalizations` for the locale
3. `ensure_screenshot_set(localization_id, display_type)`
4. **Delete** existing `appScreenshots` in that set (replace semantics)
5. For each image: `POST /appScreenshots` → binary upload via `uploadOperations` → `PATCH` `{ uploaded: true }`
6. Poll until `assetDeliveryState.state` is `COMPLETE` (or surface `FAILED`)

Credentials JWT: ES256, `aud: appstoreconnect-v1`, ~20 min expiry from `~/.config/app-store-connect/credentials.json`.

## xcresult export naming

`xcresulttool export attachments` produces names like:

```text
collections-light_0_<UUID>.png
```

Strip the `_0_<UUID>` suffix, or override with `SCREENSHOT_BASENAME` so compose/`scenes.yaml` `raw:` paths stay stable.

## Capture CLI footguns

- Appearance must be exactly `light` or `dark` — a combined arg like `"dark collections"` fails
- Scene must match the UITest method stem mapping (`collections` → `testCollectionsLight/Dark`)
- Prefer shutting idle extra booted simulators when diagnostics collection times out after a “successful” test

## scenes.yaml shape

```yaml
scenes:
  - id: collections-light
    headline: Collections for every list
    subhead: Reading, packing, tasks — your way
    template: light
    displayType: APP_IPHONE_67
    raw: raw/iphone/collections-light.png
  - id: collection-lists-dark
    headline: …
    subhead: …
    template: dark
    displayType: APP_IPHONE_67
    raw: raw/iphone/collection-lists-dark.png
    upload: false   # composed locally; skipped by upload_store_assets.py
```

`compose_store_assets.py` writes `store-assets/composed/manifest.json` consumed by `upload_store_assets.py`.
