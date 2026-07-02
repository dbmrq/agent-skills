# XcodeGen reference — agent lookup

Non-obvious fields and syntax. For full property lists see [ProjectSpec.md](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md).

## Build script phase ordering

Target scripts run in this order:

1. `preBuildScripts`
2. Compile Sources (and other native phases)
3. `postCompileScripts`
4. Other native phases (resources, frameworks, etc.)
5. `postBuildScripts`

`basedOnDependencyAnalysis` defaults `true` (skip when inputs/outputs unchanged). `showEnvVars` defaults `true`.

## Build rules

Require `filePattern` **or** `fileType`, and `script` **or** `compilerSpec`. `runOncePerArchitecture` defaults `true`.

## Dependency shorthand vs expanded form

```yaml
# Shorthand
dependencies:
  - target: MyFramework
  - framework: Vendor/My.framework
  - carthage: Alamofire
  - sdk: Contacts.framework
  - package: Yams
  - bundle: MyBundle

# Expanded (linking options)
dependencies:
  - target: MyFramework
    embed: false
    link: true
    weak: false
    destinationFilters: [iOS]
    platforms: [iOS]
  - framework: path/to/FW.framework
    implicit: true          # workspace implicit dependency
    codeSign: true
    removeHeaders: true
    copy:
      destination: frameworks
      subpath: ""
```

## Carthage path resolution

```
{CARTHAGE_BUILD_PATH}/{PLATFORM}/{Framework}.framework     # dynamic (default)
{CARTHAGE_BUILD_PATH}/{PLATFORM}/Static/{Framework}.framework  # linkType: static
{CARTHAGE_BUILD_PATH}/{Framework}.xcframework              # use framework:, not carthage:
```

`options.carthageBuildPath` and `options.carthageExecutablePath` override defaults. Mint example: `carthageExecutablePath: mint run Carthage/Carthage`.

## Swift package version specifiers

```yaml
packages:
  Remote:
    url: https://github.com/org/repo
    from: 2.0.0              # or majorVersion / minorVersion / exactVersion / version
    branch: main
    revision: abc123
    minVersion: 1.0.0
    maxVersion: 2.0.0
  GitHubShorthand:
    github: org/repo
    from: 1.0.0
  Local:
    path: ../MyPackage
    group: Domains/MyPackage
    excludeFromProject: false
```

## Aggregate targets

Separate from normal targets — used to group dependencies and run scripts without producing a product:

```yaml
aggregateTargets:
  Codegen:
    targets: [App, WidgetExtension]
    buildScripts:
      - script: ./scripts/codegen.sh
```

## Legacy (External Build System) targets

`legacy:` on a target creates an Xcode "External Build System" target — runs once even when depended on by multiple targets:

```yaml
targets:
  Codegen:
    type: ""
    platform: macOS
    legacy:
      toolPath: /usr/bin/make
      arguments: codegen
      passSettings: true
      workingDirectory: ${SRCROOT}
```

## Scheme build target map

```yaml
schemes:
  MyScheme:
    build:
      targets:
        App: all
        App: [run, test, archive]
        OtherProj/Target: [test]
      parallelizeBuild: true
      buildImplicitDependencies: true
      runPostActionsOnFailure: false
```

Build types: `run`/`running`, `test`/`testing`, `profile`/`profiling`, `analyze`/`analyzing`, `archive`/`archiving`, `all`, `none`.

## Config variant scheme generation

Given:

```yaml
configs:
  Test Debug: debug
  Test Release: release
  Staging Debug: debug
  Staging Release: release
targets:
  App:
    scheme:
      configVariants: [Test, Staging]
```

Creates schemes `App Test` and `App Staging`, each pairing debug configs for run/test/analyze and release for profile/archive.

## Test target syntax sugar

```yaml
test:
  targets:
    - UnitTests                                    # name only
    - name: UITests
      parallelizable: true
      randomExecutionOrder: true
      skippedTests: [MyClass/testFoo()]
      selectedTests: [MyClass/testBar()]          # overrides skippedTests
      location: ./test-locations/office.gpx
    - target:
        name: package: APIClient/APIClientTests
```

## `options` fields agents often miss

| Option | Default | Note |
|--------|---------|------|
| `bundleIdPrefix` | — | Auto `PRODUCT_BUNDLE_IDENTIFIER` = `{prefix}.{sanitizedTargetName}`; underscores → hyphens |
| `createIntermediateGroups` | false | Creates `Vendor/Foo` groups for `Vendor/Foo/Bar.swift` |
| `generateEmptyDirectories` | false | Empty dirs omitted from project unless true |
| `groupSortPosition` | bottom | `top` / `none` / `bottom` for folder groups vs files |
| `groupOrdering` | — | Regex `pattern` + `order` array for group sort |
| `useBaseInternationalization` | true | Set false if no `Base.lproj` to drop Base from known regions |
| `minimumXcodeGenVersion` | — | Fails generation if CLI is older |
| `projectFormat` | xcode16_0 | Required for `syncedFolder` sources |

## `putResourcesBeforeSourcesBuildPhase`

When `true`, Copy Resources runs before Compile Sources — needed for some codegen pipelines.

## Code signing

No dedicated signing DSL — use build settings (`DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE`, `PROVISIONING_PROFILE_SPECIFIER`) via `settings`, `settingGroups`, or xcconfig. Target `attributes` auto-derive `DevelopmentTeam` / `ProvisioningStyle` when consistent across configs.

## CocoaPods integration pattern

Pods are **not** listed in the spec. Workflow:

1. `xcodegen generate --use-cache`
2. `postGenCommand: pod install` (runs only on regen)
3. Open `.xcworkspace`, not `.xcodeproj`

Crashlytics via CocoaPods requires a `script_phase` in the Podfile (see XcodeGen FAQ).

## `xcodegen dump` formats

Useful for debugging merged specs:

```bash
xcodegen dump --spec project.yml --type json
xcodegen dump --spec project.yml --type yaml
```

## Real-world spec examples

- [MultiPlatformApp (SwiftUI iOS + macOS)](https://github.com/hgq287/HGSwift/tree/master/Examples/MultiPlatformApp)
- [Framework template](https://github.com/atelier-socle/FrameworkRepositoryTemplate/blob/master/project.yml)
- [Full index](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/Examples.md)
