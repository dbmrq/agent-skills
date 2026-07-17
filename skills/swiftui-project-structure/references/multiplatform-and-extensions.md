# Multiplatform Targets and Package Boundaries

## Target layout (typical Apple sample)

```
Repository/
├── MyApp.xcodeproj
├── Multiplatform/ or App/     # Shared SwiftUI app sources
├── MyAppKit/                # Local SPM — optional
├── Widgets/                 # Widget extension
├── Watch/                   # watchOS app
└── Configuration/           # xcconfigs, StoreKit, entitlements
```

**App entry** (`@main`) stays in the main app source folder. Extensions have their own `@main` (widget bundle, watch app) but **import shared packages** for models and API clients.

## Package boundary rules

| Belongs in `*Kit` / `*Data` package | Belongs in app target |
|-------------------------------------|------------------------|
| `Codable` / SwiftData models | `NavigationStack` / `TabView` shell |
| API clients, repositories | Feature screen views |
| Business rules, validation | Platform-specific scene declarations |
| Shared resources (images, JSON) | `#if os` UI adaptations at layout level |
| Types used by widgets without SwiftUI | Widget-specific `View` wrappers (thin) |

**Import direction:** App → UI package → Data package. Data package must not import SwiftUI.

### When to extract a local package

- Widget or Watch needs the same `Order` model and `OrderService`
- Second app target (e.g. admin + consumer) shares logic
- Team boundary — enforce API surface via `public` types

### When folders are enough

- Single iOS app, one extension not yet planned
- Shared code is one or two files (keep in `General/` until rule-of-three)

## Platform-specific code

**Small differences** — same file:

```swift
#if os(iOS)
.toolbar { ToolbarItem(placement: .topBarTrailing) { … } }
#elseif os(macOS)
.toolbar { ToolbarItem(placement: .automatic) { … } }
#endif
```

**Large differences** — split files:

```
Account/
├── AccountView.swift          # shared API
├── AccountView+iOS.swift      # optional: extension with platform body
└── AccountView+macOS.swift
```

Or separate platform views composed from shared presenters — presenters stay identical; containers pick layout.

## iPad / iPhone / macOS navigation

Centralize in `Navigation/`:

- iPhone: `TabView` or single `NavigationStack`
- iPad/macOS: `NavigationSplitView` with optional `.inspector`
- Read `horizontalSizeClass` or use `NavigationSplitView` column visibility APIs — do not fork entire features per platform unless layout truly diverges.

See `native-swiftui` for `NavigationSplitView` + inspector patterns.

## Widgets and App Intents

Backyard Birds widgets use App Intents and shared data from packages — the widget target should be a **thin** layer:

- Intent definitions can live in the data package or a small `Intents` module
- Widget views use models from `BackyardBirdsData`
- No duplicate networking in the widget extension

## XcodeGen note

If the project uses XcodeGen, declare local packages under `packages:` and link per-target. See the **xcodegen** skill for traps, or **ios-bootstrap** when scaffolding a new app with quality gates.

## Environment and configuration

- **Per-target:** Info.plist, entitlements, App Groups (widget ↔ app data sharing)
- **Shared:** `Configuration/` folder for `.xcconfig`, StoreKit files, CI schemes
- **Secrets:** not in repo — xcconfig overlays or CI injection
