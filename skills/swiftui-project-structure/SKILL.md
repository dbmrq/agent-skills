---
name: swiftui-project-structure
description: >-
  Organize SwiftUI app repositories, folders, Swift packages, and architecture
  layers following Apple sample projects (Backyard Birds, Food Truck) and WWDC
  guidance. Use when scaffolding a new SwiftUI app, reorganizing features into
  modules, choosing MV vs ViewModel/Store layers, splitting SPM packages,
  structuring multiplatform targets (iOS/macOS/watchOS/widgets), wiring App/Scene
  entry points, or reviewing project-level architecture — not individual view bodies.
---

# SwiftUI Project Structure

Organize SwiftUI projects the way Apple’s sample apps do: **feature-first folders**, **direct model observation**, and **packages only where sharing is real**. Avoid defaulting to layer-based `Views/` / `ViewModels/` / `Models/` trees or per-screen ViewModels.

**Skill split:**
- **`swiftui-project-structure`** (this skill) — repo layout, targets, packages, architecture layers
- **`swiftui-view-composition`** — extracting views inside a feature; one view per file
- **`native-swiftui`** — which system components and styles to use
- **`swiftui-expert-skill`** — property wrappers, performance, concurrency ([avdlee/swiftui-agent-skill](https://github.com/avdlee/swiftui-agent-skill); install via `./scripts/install-all.sh`)
- **`ios-bootstrap`** — greenfield / onboarding: XcodeGen starter + ai-rules quality gates
- **`xcodegen`** — deep `project.yml` traps once the repo already uses XcodeGen

## Agent workflow

1. **Inspect the repo** — note targets (app, widgets, watch), existing packages, and whether groups mirror the filesystem.
2. **Pick organization axis** — feature/domain folders (default) vs Swift packages (when code is shared across targets or apps).
3. **Pick architecture depth** — start with MV (view ↔ `@Observable` model); add layers only for a concrete reason (see [architecture-decisions.md](references/architecture-decisions.md)).
4. **Place new files** — co-locate by user-facing feature; do not create global `Views/` or `ViewModels/` buckets.
5. **Wire dependencies at `App`** — model containers, shared stores, and environment injection belong in the `@main` app type or scene root.
6. **Mirror structure in tests** — tests grouped by feature/flow, not by file type alone.
7. **Delegate view extraction** — once folders are right, use `swiftui-view-composition` for large `body` properties.

## App → Scene → View (entry-point rules)

Apple’s SwiftUI stack has three roles. Keep each in its lane:

| Layer | Responsibility | Typical types |
|-------|----------------|---------------|
| **App** (`@main`) | Entry point; owns long-lived app state; declares scenes | `BackyardBirdsApp`, `Food_TruckApp` |
| **Scene** | Distinct UI region (window, settings, document group) | `WindowGroup`, `Settings`, `DocumentGroup` |
| **View** | Rendering and local interaction | Feature views, rows, sheets |

**Non-obvious rules:**
- Inject shared models in `App.body` (or the scene root), not deep in feature views — `.environment(model)` for `@Observable`, model container for SwiftData.
- `ContentView` (or a `Navigation/` root) orchestrates top-level tabs/split view; it is not a junk drawer for unrelated features.
- Platform-specific scenes (macOS `Settings`, document-based `DocumentGroup`) live in the app target or a small platform folder — not mixed into every feature.
- Extensions (Widgets, Watch) are **separate targets** that depend on shared packages — do not duplicate business logic in the extension target.

```swift
@main
struct MyApp: App {
    @State private var account = AccountModel()

    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environment(account)
        }
        #if os(macOS)
        Settings { SettingsView() }
        #endif
    }
}
```

## Folder organization (default)

### Prefer feature/domain folders over technical layers

**Do not** create top-level `Views/`, `ViewModels/`, `Models/` — agents default to this and it fights Apple’s samples.

**Do** name folders after user-facing areas. Apple’s Backyard Birds `Multiplatform/` uses `Birds/`, `Backyards/`, `Shop/`, `Account/` — not `Features/Birds/ViewModels/`.

```
AppTarget/
├── MyApp.swift
├── ContentView.swift          # or Navigation/Root…
├── Navigation/                # app-wide routing shell
├── General/                   # cross-feature helpers (Apple uses this)
├── Account/                   # domain feature
│   ├── AccountView.swift
│   ├── AccountRow.swift
│   └── …
├── Orders/
│   ├── OrdersView.swift
│   ├── OrderRow.swift
│   └── OrderDetailView.swift
└── Assets.xcassets
```

Within a feature, **co-locate** views, feature-specific models, and small helpers. A `Components/` subfolder is fine for feature-private UI pieces — not a global `Shared/Views` dump.

### When to add `Models/`, `Services/`, or `Shared/`

| Folder | Use when |
|--------|----------|
| Feature folder | Default — everything for one user-facing area |
| `General/` | App-wide utilities, small extensions, env keys (Apple pattern) |
| `Navigation/` | Root `NavigationStack`/`NavigationSplitView`, tab selection, deep-link routing |
| Local `Models/` inside a package | Types shared across features **within that package only** |
| Top-level `Shared/` | Design primitives after rule-of-three (`swiftui-view-composition`) — not the first resort |
| Top-level `Services/` | Networking/persistence used by many features — prefer injecting into environment |

See canonical Apple layouts: [apple-sample-layouts.md](references/apple-sample-layouts.md).

## Swift packages (when folders are not enough)

Apple splits **Backyard Birds** into `BackyardBirdsData` + `BackyardBirdsUI` packages; **Food Truck** uses `FoodTruckKit`. Use SPM when:

- Code is consumed by **multiple targets** (app + widgets + watch)
- Code may ship in **more than one app**
- A boundary is stable enough to enforce import direction (data → UI, not reverse)

**Typical package split:**

| Package | Contents |
|---------|----------|
| `*Kit` / `*Data` | Models, persistence, API clients, resources — **no SwiftUI views** |
| `*UI` | Reusable SwiftUI components, styles — depends on data package if needed |
| App target | Scenes, feature screens, navigation wiring |

Do **not** create packages prematurely for a single-target app — folders are enough until a second consumer exists.

Package and multiplatform target patterns: [multiplatform-and-extensions.md](references/multiplatform-and-extensions.md).

## Architecture layers (what to add beyond MV)

Apple’s samples use **Model–View**: views observe `@Observable` (or legacy `ObservableObject`) models directly. SwiftUI’s property wrappers already bind state — a **per-screen ViewModel is usually redundant**.

Add a layer only when:

| Need | Add | Avoid |
|------|-----|-------|
| Shared app state across many features | `@Observable` **Store** per bounded context, injected via `.environment` | One ViewModel per screen |
| Screen fetches data, children display it | **Container** view (loads state) + **Presenter** child views | ViewModel that only forwards model properties |
| Large form validation / UI-only state | Small `struct` holding form fields, or methods on the model | 200-line ViewModel mirroring every field |
| Navigation across deep stacks / push from notification | Coordinator or dedicated `Navigation/` module | Navigation scattered in every feature view |
| Flattening API DTOs for display | View-specific formatter or lightweight adapter | Full MVVM stack for a list screen |

**Store ≠ ViewModel:** A Store is an aggregate for a **bounded context** (e.g. `FoodTruckModel`, cart + orders), not a 1:1 screen wrapper. Introduce a new observable type when there is a **new source of truth**, not because you added a new view.

Full decision guide: [architecture-decisions.md](references/architecture-decisions.md).

## Container / presenter at project level

Apple and community MV guidance use **container** views for data loading and **presenter** views for display:

- **Container** — owns `.task`, `@State` for loaded data, error/loading flags; passes `let` data down
- **Presenter** — `let` inputs only; easy to preview and reuse

```swift
// Orders/OrdersView.swift — container (feature screen)
struct OrdersView: View {
    @Environment(OrderStore.self) private var store

    var body: some View {
        Group {
            if store.isLoading { ProgressView() }
            else if let error = store.error { ContentUnavailableView("Error", description: Text(error.localizedDescription)) }
            else { OrdersTable(orders: store.orders) }
        }
        .task { await store.loadOrders() }
    }
}

// Orders/OrdersTable.swift — presenter
struct OrdersTable: View {
    let orders: [Order]
    var body: some View { … }
}
```

Do not move containers into a global `ViewModels/` folder — keep them beside their presenters in the feature folder.

## Multiplatform and platform-specific code

- **Shared app code** often lives in `Multiplatform/` (Backyard Birds) or the main `App/` folder (Food Truck) with platform targets wrapping it.
- Use `#if os(iOS)` / `#if os(macOS)` for small differences; split files with `#if` only when the platform body diverges substantially.
- **Strings and assets** — `Localizable.xcstrings`, asset catalogs at the shared level; platform-specific plist/entitlements per target.
- **Navigation** — `NavigationSplitView` + inspector on iPad/macOS; `NavigationStack` or tab shell on iPhone — adapt in `Navigation/`, not inside every row view.

## Testing layout

Mirror **features and flows**, not only technical layers:

```
Tests/
├── OrderStoreTests.swift      # or Orders/OrderStoreTests.swift
├── OrdersFlowUITests.swift
└── TestSupport/
    ├── Fixtures.swift
    └── …
```

- Unit-test **models and stores** (business rules, parsing, persistence).
- UI tests target **user flows** across screens.
- Do not require a ViewModel layer just to make views testable — extract logic to models or use ViewInspector for view logic when needed.

## Xcode groups

- **Filesystem = groups** — if you reorganize folders, update the Xcode project (or `project.yml`) so groups match; orphaned groups confuse agents and humans.
- **One primary type per file**; file name matches the type (`OrderRow.swift`).
- **Avoid** a single `ContentView.swift` that grows without bound — split by feature when adding the second screen.

## Anti-patterns (agents often get these wrong)

| Anti-pattern | Why it fails | Prefer |
|--------------|--------------|--------|
| `Views/HomeView.swift` + `ViewModels/HomeViewModel.swift` globally | Layer-first; duplicates Apple’s approach | `Home/HomeView.swift` + model/store in environment |
| ViewModel per screen by default | Extra sources of truth; fights SwiftUI bindings | Direct `@Observable` model observation |
| Business logic only in ViewModels | Hard to test without unnecessary layers | Models/stores with behavior; thin views |
| One giant `Shared/` for all reuse | Unclear ownership | Feature-local first; package after rule-of-three |
| Widget target copies API code | Drift and duplication | `*Kit` package imported by app + widget |
| `ObservableObject` for all new code | Legacy | `@Observable` + `@State` / `@Environment` |

## Checklist

Before finishing structural work:

- [ ] Folders grouped by **feature/domain**, not `Views/`/`ViewModels/` at repo root
- [ ] `App` wires shared models via `.environment` / model container
- [ ] New observable types justified by **bounded context**, not screen count
- [ ] Packages only where **multiple targets** or apps consume the code
- [ ] Widgets/Watch are separate targets depending on shared packages
- [ ] `Navigation/` (or equivalent) owns app shell routing
- [ ] Tests align with **features/flows**
- [ ] Xcode groups match filesystem
- [ ] Large view bodies delegated to `swiftui-view-composition`

## References

- [apple-sample-layouts.md](references/apple-sample-layouts.md) — Backyard Birds & Food Truck repo trees
- [architecture-decisions.md](references/architecture-decisions.md) — MV, Store, ViewModel, coordinator tradeoffs
- [multiplatform-and-extensions.md](references/multiplatform-and-extensions.md) — targets, SPM boundaries, `#if os`

## External sources

- [SwiftUI App Structure (Apple)](https://developer.apple.com/documentation/swiftui/app)
- [App organization (Apple)](https://developer.apple.com/documentation/swiftui/app-organization)
- [Managing user interface state (Apple)](https://developer.apple.com/documentation/swiftui/managing-user-interface-state)
- [WWDC20 — SwiftUI App Structure](https://developer.apple.com/videos/play/wwdc2020/10037/)
- [WWDC20 — Data Essentials in SwiftUI](https://developer.apple.com/videos/play/wwdc2020/10040/)
- [Backyard Birds sample](https://github.com/apple/sample-backyard-birds)
- [Food Truck sample](https://github.com/apple/sample-food-truck)
- [Swift forums — Apple-recommended architecture](https://forums.swift.org/t/what-is-the-architecture-officially-recommended-by-apple-for-swiftui-applications/44930)
