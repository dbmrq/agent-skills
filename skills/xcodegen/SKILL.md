---
name: xcodegen
description: >-
  Author and debug XcodeGen project.yml specs — merge semantics, settings
  pitfalls, source filtering, dependency integration, multiplatform targets,
  schemes, and cache/CLI behavior. Use when creating or editing project.yml,
  project.yaml, XcodeGen specs, generated .xcodeproj issues, or when the user
  mentions XcodeGen, xcodegen generate, or spec-driven Xcode projects.
---

# XcodeGen

Spec reference: [ProjectSpec](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md) · [Usage](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/Usage.md)

Assume the agent knows YAML and that XcodeGen generates `.xcodeproj` from a spec. This skill covers behavior that is easy to get wrong.

## Agent workflow

1. Read existing `project.yml` and any `include:` files before editing.
2. After changes, run `xcodegen generate` (add `--use-cache` only when the repo already uses caching hooks).
3. On unexpected output, run `xcodegen dump --type json` to inspect the **resolved** spec after includes/templates merge.
4. Build in Xcode or `xcodebuild` to confirm targets, schemes, and dependencies — generation succeeding does not prove linking is correct.

## Include merge semantics

Includes merge **additively** by default:

| Existing + new | Result |
|----------------|--------|
| Both dicts | Deep merge |
| Both arrays | Concatenate (new appended) |
| Otherwise | New replaces old |

**`:REPLACE` suffix** — force wholesale replacement instead of merge:

```yaml
include:
  - base.yml
targets:
  MyTarget:          # defined in base.yml
    sources:REPLACE:
      - only/these/sources
```

Other include gotchas:

- `relativePaths: false` on an include makes paths in that file relative to the **root** spec, not the included file.
- `enable: ${ENV_VAR}` can conditionally skip an include.
- Target names can be overridden by adding `name:` on a target entry.
- Comma-separated `--spec a.yml,b.yml` merges multiple root specs (same flags apply to all).

## Settings traps

### Silent ignore of simple maps

If `settings` uses `groups`, `base`, or `configs`, a **flat** key-value map at the same level is **silently ignored**:

```yaml
# MARKETING_VERSION is IGNORED; only CURRENT_PROJECT_VERSION applies
settings:
  MARKETING_VERSION: 100.0.0
  base:
    CURRENT_PROJECT_VERSION: 100.0
```

Merge order within a Settings object: `groups` → `base` → `configs`.

### Config name matching

`configs:` keys match **case-insensitively** and by **substring** — except exact matches, which apply only to that config:

```yaml
settings:
  configs:
    staging:          # applies to "Staging Debug" AND "Staging Release"
      SWIFT_ACTIVE_COMPILATION_CONDITIONS: STAGING
    Release:          # applies ONLY to "Release", not "Staging Release"
      SWIFT_OPTIMIZATION_LEVEL: -O
```

### Presets vs xcconfig hierarchy

XcodeGen layers settings: setting presets → groups/base/configs → **xcconfig** (highest). xcconfig values also overwrite preset defaults. Build setting keys must be the **raw** names (`IPHONEOS_DEPLOYMENT_TARGET`), not Xcode display titles.

`options.settingPresets: none` disables Xcode-like defaults — useful when xcconfig owns everything, but then you must set all required settings explicitly.

### Custom configs drop preset build settings

Config types other than `debug` or `release` (e.g. `none`) receive **no** default Debug/Release build settings from XcodeGen:

```yaml
configs:
  Debug: debug
  Beta: release      # gets release-type defaults
  Custom: none       # gets NO debug/release defaults
```

`options.defaultConfig` sets the CLI default; if unset, the **first config alphabetically** wins.

## Sources — filtering and representation

### excludes / includes paths

`excludes` and `includes` are relative to the source entry's `path`, **not** `project.yml`. Globstar `**` is enabled (Bash 4 glob). When both are set, **excludes win** over includes.

### Source `type` changes Xcode behavior

| type | Effect |
|------|--------|
| `group` (default for extensionless dirs) | Files tracked individually; new files on disk are **not** auto-picked up |
| `folder` | Folder reference; contents change on disk without editing spec |
| `syncedFolder` | Xcode 16+ buildable folder; needs `options.projectFormat: xcode16_0` or newer |
| `file` | Single file reference |

`options.defaultSourceDirectoryType` sets the default when a directory omits `type`.

### Other source gotchas

- `Info.plist` is **never** added to any build phase, regardless of `buildPhase`.
- `optional: true` skips missing-path validation.
- `inferDestinationFiltersByPath: true` filters by `**/ios/*` and `*_iOS.swift` path patterns; ignored if `destinationFilters` is set.
- Overriding `options.fileTypes` for a built-in extension requires providing **all** fields for that extension.

## Multiplatform and destinations

### `platform: [iOS, tvOS]` (array)

Generates **separate targets** per platform with default suffix `_${platform}` (override via `platformPrefix` / `platformSuffix`). `${platform}` in the spec is substituted. Shared `PRODUCT_NAME` defaults to the logical name so imports stay consistent.

### `supportedDestinations` (Xcode 14+)

Single target, multiple destinations. `platform` becomes `auto`. Use `destinationFilters` on sources and dependencies.

**watchOS apps** — `supportedDestinations` does **not** support watchOS for app targets. Create a separate target with `platform: watchOS`.

`inferDestinationFiltersByPath` helps split shared source trees; explicit `destinationFilters` is more predictable.

## Dependencies — integration specifics

### Target / project reference

```yaml
projectReferences:
  FooLib:
    path: path/to/FooLib.xcodeproj
targets:
  App:
    dependencies:
      - target: FooLib/SomeTarget   # ProjectName/TargetName
```

### Carthage

- `carthage:` helper is for `.framework` in `Carthage/Build/PLATFORM/` — **not** XCFrameworks. For XCFrameworks use `framework:`.
- `findFrameworks: true` (or global `options.findCarthageFrameworks`) reads Carthage `.version` files — **Carthage must be built before** `xcodegen generate`.
- The name in the spec must match the `.version` filename, which can differ from repo or framework name.
- Static Carthage frameworks live under `PLATFORM/Static/`; set `linkType: static`.
- `directlyEmbedCarthageDependencies` defaults `true` except for iOS/tvOS/watchOS **applications** (those use the copy-frameworks script).
- `visionOS` does not support Carthage.

### Swift Packages

- Declared at project `packages:`; linked per-target via `dependencies: - package: Name` (optional `product:` or `products:`).
- **Known limitation:** SPM integration breaks when the project has configs beyond `Debug`/`Release` ([SR-10927](https://bugs.swift.org/browse/SR-10927)).
- Pin versions via `ProjectName.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
- Local packages default to a `Packages` group; `localPackagesGroup: ""` puts them at project root. `excludeFromProject: true` omits from generated project.

### Static library + bundle in another project

```yaml
dependencies:
  - bundle: MyResourceBundle   # copies pre-built bundle into resources
```

Only for target types that can copy resources; pairs with static libs that vend bundles elsewhere.

### Linking defaults worth overriding

| Property | Default nuance |
|----------|----------------|
| `embed` | `true` for apps, `false` otherwise |
| `link` | Depends on dependency + target types (static libs link only to executables by default) |
| `requiresObjCLinking` | `true` for `library.static`; adds `-ObjC` to dependents — leave alone unless pure Swift with no ObjC categories |
| `transitivelyLinkDependencies` | `false` at project level; set `true` to pull transitive deps (and embed them for bundles/apps) |

### SDK dependency root

```yaml
dependencies:
  - sdk: Platforms/iPhoneOS.platform/Developer/Library/Frameworks/XCTest
    root: DEVELOPER_DIR
```

Default `root` is `BUILT_PRODUCTS_DIR`.

## Schemes

### Auto-generated target schemes (`target.scheme`)

`configVariants` creates one scheme per variant, matching configs whose names **contain** the variant string (e.g. `Staging` → `Staging Debug` / `Staging Release`).

### Manual schemes

- `schemePathPrefix` defaults to `"../../"` (standalone `.xcodeproj`). Use `"../"` inside `.xcworkspace` — affects relative paths like StoreKit configs and GPX files.
- Custom GPX for `simulateLocation` must be listed in `fileGroups` to be found.
- **Test plans are not generated** — create `.xctestplan` in Xcode, check in, reference by path. Renaming test targets may require updating plans in Xcode.
- `selectedTests` overrides `skippedTests` when both are set.

### Coverage / test target references

```yaml
coverageTargets:
  - MyTarget
  - ExternalProj/OtherTarget
  - package: LocalPackage/TestTarget
```

## Generated plists

`info:` and `entitlements:` **rewrite files on every generation**. Do not hand-edit generated plists without moving the source of truth into the spec. `INFOPLIST_FILE` in settings overrides auto-generated `info:` for that config.

Auto-generated Info.plist keys include bundle identifiers and version fields; `CFBundleExecutable` is **not** generated for `bundle` targets.

## Cache and CLI behavior

```bash
xcodegen generate --spec path/to/project.yml --project output/dir
xcodegen generate --use-cache          # skip regen when spec unchanged
xcodegen cache                         # refresh cache without generating (for git hooks)
xcodegen dump --type json              # resolved spec after includes/templates
```

| Command / option | Behavior |
|------------------|----------|
| `--use-cache` | Skips project write when spec hash matches cache |
| `preGenCommand` | Runs **before** cache check — executes even when generation is skipped |
| `postGenCommand` | Runs **only after** actual regeneration — safe for `pod install` |
| `--only-plists` | Regenerates plists only, skips `.xcodeproj` |

Recommended git hooks (from XcodeGen FAQ): `post-checkout` / `post-merge` / `post-rewrite` → `xcodegen generate --use-cache`; `pre-commit` → `xcodegen cache`.

Environment variables in spec strings: `${VAR_NAME}`.

## Validation toggles

When sharing YAML across projects or generating in CI without all files present:

```yaml
options:
  disabledValidations:
    - missingConfigs
    - missingConfigFiles
    - missingTestPlans
```

## Common failure modes

| Symptom | Likely cause |
|---------|----------------|
| Setting in YAML has no effect | Flat settings mixed with `base`/`configs`/`groups`; or xcconfig overrides it |
| Files missing from target | Wrong `excludes` path (relative to source `path`, not repo root); or `type: group` vs `folder` mismatch |
| Carthage framework not found | Not built yet; wrong `.version` name; XCFramework listed as `carthage:` instead of `framework:` |
| SPM resolution fails | Extra configs beyond Debug/Release |
| Scheme can't find GPX / StoreKit file | Missing `fileGroups` entry or wrong `schemePathPrefix` |
| Duplicate symbols / wrong linking | `transitivelyLinkDependencies` or `requiresObjCLinking` mismatch |
| `pod install` not needed but runs | `postGenCommand` in spec without `--use-cache`, or cache invalidated |

## Templates

`targetTemplates` / `schemeTemplates` merge via `templates:` list. Placeholders:

- `${target_name}` / `${scheme_name}` — resolved name
- `${attributeName}` — from `templateAttributes` on the referencing target/scheme

Templates compose: a scheme template can reference another scheme template via nested `templates:`.

## Additional reference

For dependency option matrices, build script phase ordering, and breakpoint/scheme action fields, see [reference.md](reference.md).
