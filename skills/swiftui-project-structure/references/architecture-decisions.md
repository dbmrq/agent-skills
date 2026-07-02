# Architecture Layer Decisions

Apple does not mandate MVVM. Official samples and WWDC “Data Essentials” guidance favor **views observing models** with shared state injected from the app entry point. This reference helps agents choose layers without over-engineering.

## Default: Model–View (MV)

```
@Observable Model/Store  ←——→  SwiftUI View
```

- Views use `@State`, `@Environment`, `@Bindable` for observation — they already act as the presentation layer.
- Business logic belongs in **models** (structs with behavior) or **stores** (observable aggregates), not in a dedicated class per screen.
- Async work is triggered from views via `.task` / `.task(id:)` but implemented on models or services.

**Start here.** Add complexity only when a concrete problem appears.

## When a per-screen ViewModel is justified

Rare cases — not the default for every `FooView`:

| Scenario | Approach |
|----------|----------|
| Large form with validation messages | Small `struct` for form state + validation methods, or validation on the model |
| Heavy UI-only state unrelated to domain | `@State` on the container view, or a feature-local struct |
| Bridging legacy UIKit coordinator | Adapter type at the boundary — not a pattern for pure SwiftUI screens |
| Flattening many API fields for one screen | Formatter / `display*` properties on the model or a tiny read-only adapter |

**Red flag:** `HomeViewModel` that only exposes `@Published var items` copied from `HomeStore` — delete the middle layer.

## Store (aggregate model)

A **Store** is an `@Observable` (or `ObservableObject`) type scoped to a **bounded context** — cart, account, food truck operations — not to a single screen.

WWDC20 *Data Essentials* shows a single interface through which views access app data. In Food Truck, `FoodTruckModel` coordinates donuts, orders, and truck state.

Rules:
- One store per bounded context, not per view.
- Inject at `App` / scene root: `.environment(store)`.
- Stores call **services** (HTTP, persistence); views call **stores** or **models**.
- Multiple stores are fine when contexts are independent (e.g. `AccountStore` + `CatalogStore`).

```swift
@Observable
@MainActor
final class OrderStore {
    var orders: [Order] = []
    var isLoading = false
    var error: Error?

    func loadOrders() async { … }
}
```

## Container vs presenter (not MVVM)

Distinct from ViewModel layering:

| Role | Owns | Does not own |
|------|------|--------------|
| **Container** | `.task`, loading/error state, environment access | Layout details of every row |
| **Presenter** | `let` inputs, layout, light formatting | Network calls, global state mutation |

Containers and presenters live in the **same feature folder**. The container is often the “screen” (`OrdersView`); presenters are rows, sections, or sheets (`OrderRow`).

This is the pattern AzamSharp and Apple samples use for list screens — the “screen” fetches; child views render.

## Coordinator / navigation module

Add when:
- Push notifications or URLs must open **deep** destinations
- Multiple features share complex sheet/full-screen cover routing
- `NavigationStack` path state becomes unwieldy inside one view

Place routing in `Navigation/` (or a small coordinator type), not inside every presenter.

Steamclock’s “NiceArchitecture” uses **ViewCoordinators** for this — optional pattern when navigation complexity warrants it, not a default for simple apps.

## MVVM vs MV — decision table

| Question | If yes → |
|----------|----------|
| Does this screen introduce a new source of truth? | New `@Observable` store/model |
| Does the view only display data passed from parent? | Presenter view (`let` only) |
| Does the screen load data for its subtree? | Container view + `.task` |
| Is state shared across unrelated features? | Environment-injected store |
| Is logic testable without UI? | Move to model/store; unit test there |
| Would ViewModel only forward model properties? | **Skip ViewModel** |

## State injection cheat sheet (modern)

| Scope | Mechanism |
|-------|-----------|
| View-local | `@State` |
| Child modifies parent | `@Binding` |
| Shared app model | `@Environment(Model.self)` with `.environment(model)` |
| SwiftData | `.modelContainer` + `@Query` / `modelContext` |
| Legacy shared object | `@EnvironmentObject` (prefer migrating to `@Observable` + `@Environment`) |

## Testing without ViewModels

- **Unit tests:** models, stores, parsers, persistence.
- **UI tests:** flows across screens.
- **View logic:** extract pure functions (sorting, validation) to testable types; or ViewInspector for isolated view tests.

Do not introduce ViewModels solely to make views unit-testable — that trades one problem for architectural debt.

## Related reading

- [MV State / MV pattern (AzamSharp)](https://azamsharp.com/2022/08/09/intro-to-mv-state-pattern.html)
- [Building large-scale apps (AzamSharp)](https://azamsharp.com/2023/02/28/building-large-scale-apps-swiftui.html)
- [Nice Architecture (Steamclock)](https://steamclock.com/blog/2024/04/nice-architecture) — MVVM + coordinators when navigation complexity grows
