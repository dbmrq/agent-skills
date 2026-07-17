# Periphery traps (ai-rules-ios)

Use with `./scripts/deadcode.sh` (always passes `--strict`). Canonical plug-in: [dbmrq/ai-rules-ios](https://github.com/dbmrq/ai-rules-ios).

## No baselines

- Do **not** add `baseline:` to `.periphery.yml` or commit `.periphery.baseline.json`.
- Fix findings: delete dead code, demote redundant `public` → `internal`, or wire real call sites.
- Historical chip-away (if a legacy tree still has debt): `.ai-rules/quality/debt/RATCHET.md`.

## Build path: `build` then `--skip-build`

Periphery’s default path often uses `build-for-testing`, which **still compiles tests**. A broken test target fails the scan even with `exclude_tests: true`.

Preferred recovery:

```bash
xcodebuild -scheme <App> \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/<App>PeripheryDD \
  build CODE_SIGNING_ALLOWED=NO

./scripts/deadcode.sh --skip-build \
  --index-store-path /tmp/<App>PeripheryDD/Index.noindex/DataStore
```

Keep tests compiling for CI; use this path when unblocking deadcode independently.

## Index store races

- Do **not** point Periphery at live Xcode `DerivedData/…/Index.noindex` while Xcode is open — false positives and “declaration conflict / USR already indexed” noise are common.
- Prefer a dedicated DerivedData under `/tmp/<App>PeripheryDD` (same as above).
- `debt-report.sh` follows that convention; if it reports huge debt after a clean `deadcode.sh`, the index store is wrong/stale — rebuild under `/tmp/…` and re-run.

## Redundant `public`

- “Redundant public accessibility (not used outside of Module)” → remove `public` (use `internal`) for same-module APIs.
- Keep `public` only on real cross-module package surface.
- Do **not** leave `--disable-redundant-public-analysis` as a permanent suppression.

## Assign-only and demo symbols

- Assign-only properties: read them, remove them, or stop storing unused fields.
- Demo / screenshot helpers Periphery cannot see as used: give a real call site, or delete.

## After API cleanup

Re-run `./scripts/check.sh` (length/access changes) and `./scripts/deadcode.sh`. Never “fix” unused code by growing a baseline.
