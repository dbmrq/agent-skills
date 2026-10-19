# Asset Library API — upload and placement

All paths are App Store Connect API v1 (`https://api.appstoreconnect.apple.com/v1`).
`{APP_ID}` is the ASC app resource id (not the bundle id).

## 1. Discover specs

```http
GET /apps/{APP_ID}/assetLibrary        → appAssetLibraries id (often = app id)
GET /appAssetLibraryRefData            → features, placementTypes, imageSpecs, videoSpecs
```

Relevant placement types (group `DEFAULT_PROFILE`, `maxCount: 1`):

- `PRODUCT_PAGE_HEADER_ASSET`
- `APP_STORE_SEARCH_RESULTS_ASSET`

Specs (2026 era): header image 3840 × 1646 PNG or universal 5244 × 2950 PNG;
search image 3:2 1920–3840 × 1280–2560 PNG/JPG; videos 5–30 s, 30/60 fps, H.264;
header video exactly 3840 × 1646. No alpha.

## 2. Reserve + upload an asset

```http
POST /appAssetLibraryImages
{
  "data": {
    "type": "appAssetLibraryImages",
    "attributes": {
      "fileName": "header-<contenthash>.png",
      "fileSize": 1234567,
      "category": "CREATIVE_ASSETS",
      "referenceName": "header image <contenthash>"
    },
    "relationships": {
      "assetLibrary": { "data": { "type": "appAssetLibraries", "id": "{APP_ID}" } }
    }
  }
}
```

Videos use `/appAssetLibraryVideos`, `type: appAssetLibraryVideos`, plus
`"previewFrameTimeCode": "00:00:02:00"`.

The response has `uploadOperations: [{method, url, length, offset, requestHeaders}]`.

- **Multi-part uploads**: send `bytes[offset:offset+length]` to each operation's URL
  (videos > ~5 MB arrive in several parts). Send no Authorization header.
- Then confirm:

```http
PATCH /appAssetLibraryImages|Videos/{ASSET_ID}
{ "data": { "type": "...", "id": "...", "attributes": { "uploaded": true } } }
```

- Poll `GET /appAssetLibraryImages|Videos/{ASSET_ID}`:
  `AWAITING_UPLOAD → UPLOAD_COMPLETE → COMPLETE → PREPARE_FOR_SUBMISSION`.
  A size mismatch here (`STATE_ERROR.ASSET_SIZE_MISMATCH`) means a part was sent
  with the wrong slice.

**Duplicates**: the library dedupes by `fileName` *and* `referenceName`;
re-uploading the same name returns `409 ENTITY_ERROR.ATTRIBUTE.INVALID.DUPLICATE`.
Content-address both (short SHA-256 of the bytes) so iterations get new names and
identical re-runs reuse existing assets. A pending `AWAITING_UPLOAD` asset can be
resumed (GET it for fresh upload operations, PUT parts, PATCH uploaded) instead of
creating a new one.

## 3. Place the asset

Find the version localization first:

```http
GET /appStoreVersions/{VERSION_ID}/appStoreVersionLocalizations
```

```http
POST /appAssetLibraryPlacements
{
  "data": {
    "type": "appAssetLibraryPlacements",
    "attributes": {
      "placementType": "PRODUCT_PAGE_HEADER_ASSET",
      "placementGroup": "DEFAULT_PROFILE"
    },
    "relationships": {
      "video": { "data": { "type": "appAssetLibraryVideos", "id": "{VIDEO_ID}" } },
      "appStoreVersionLocalization": {
        "data": { "type": "appStoreVersionLocalizations", "id": "{LOC_ID}" }
      }
    }
  }
}
```

Use the `image` relationship for images. To replace a placement: list, delete, create.

- List: `GET /appStoreVersionLocalizations/{LOC_ID}/placements` — **the relationship
  is `placements`** (`appAssetLibraryPlacements` does not exist).
- Delete: `DELETE /appAssetLibraryPlacements/{PLACEMENT_ID}`.
- An asset cannot be deleted while placed:
  `409 STATE_ERROR.ASSET_HAS_PLACEMENTS` — remove placements first.
- On a pre-submission version the placement reports `state: ACTIVE` immediately,
  but it goes live with the version / asset review.

## 4. Review and release notes

- Creative assets are reviewed separately. They can be submitted with the app
  version or from the Asset Library (the API exposes `reviewSubmissions`; the
  asset relationship used in practice is `appAssetLibraryImage`).
- The media type of a placement is fixed on create; one asset per placement type
  (`maxCount: 1`). Upload the still as a fallback (`--no-place`), but place either
  the video or the image.
- Apps without an editable version (`READY_FOR_SALE`): update the live product page
  with a metadata-only submission, or add the assets with the next version. Older
  SDK builds also won't show the iOS 27-optimized presentation until recompiled.
