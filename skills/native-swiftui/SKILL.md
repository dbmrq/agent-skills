---
name: native-swiftui
description: >-
  Build iOS apps that look and behave like native Apple software by preferring
  highest-level SwiftUI components, system styles, semantic colors, and standard
  navigation structures. Use when creating or reviewing SwiftUI UI, choosing
  between custom vs built-in controls, styling buttons and cards, or when the
  user wants a native iOS look, HIG-aligned layouts, or out-of-the-box SwiftUI
  APIs instead of custom implementations.
---

# Native SwiftUI

Produce iOS interfaces that feel native by **defaulting to Apple's ready-made SwiftUI components and styles** before writing custom views. Custom UI is the exception, not the starting point.

**Skill split:**
- **`native-swiftui`** (this skill) — *what* Apple components and system styles to use
- **`swiftui-view-composition`** — *how* to structure and refactor large views into reusable pieces
- **`swiftui-expert-skill`** — state management, performance, concurrency (if installed)

## Agent workflow

1. **Check deployment target** — use the newest APIs the minimum iOS version supports.
2. **Pick structure first** — `NavigationStack` / `NavigationSplitView` + `.inspector` before inventing custom chrome.
3. **Pick components second** — scan [built-in-components.md](built-in-components.md) for a system control that fits.
4. **Style at the root** — `.tint`, `.buttonStyle`, `.groupBoxStyle` on `WindowGroup` or screen containers (see [styling.md](styling.md)).
5. **Verify native feel** — system colors, SF Symbols, Dynamic Type, Dark Mode, accessibility labels.
6. **Reject custom reimplementations** — if Apple ships it, use it.
7. **Structure large screens** — if `body` is hard to scan, apply `swiftui-view-composition` (extract `View` structs before custom modifiers).

## Golden rules

| Prefer | Avoid |
|--------|-------|
| `GroupBox`, `Form`, `DisclosureGroup` for grouped content | Custom `RoundedRectangle` + shadow "cards" |
| `.buttonStyle(.borderedProminent)` / `.bordered` + `ButtonRole` | Hand-rolled button backgrounds and borders |
| Semantic colors (`.primary`, `.secondary`, `.tint`, `.teal`, `.mint`) | Hard-coded hex/RGB/`Color(red:green:blue:)` |
| `Label`, `LabeledContent` for icon+text rows | Manual `HStack` of `Image` + `Text` |
| `ContentUnavailableView` for empty states | Custom empty-state illustrations |
| `NavigationStack`, `NavigationSplitView`, `.inspector` | Custom nav bars, sidebars, detail panes |
| `ShareLink`, `ColorPicker`, `PasteButton`, `RenameButton` | UIKit bridges or bespoke controls |
| SF Symbols | Custom icon assets (unless branding requires) |
| `@Observable` + `@State` | `ObservableObject` / `@Published` in new code |
| `.task` / `.task(id:)` | `onAppear { Task { } }` without cancellation |

## App structure and navigation

### iPhone
- **`NavigationStack`** for drill-down flows; `navigationDestination(for:)` for type-safe pushes.
- **`TabView`** with the `Tab` API (not deprecated `tabItem`).
- **`.sheet(item:)`** for model-driven modals; sheet content owns its actions and calls `dismiss()`.

### iPad / macOS
- **`NavigationSplitView`** for sidebar + detail; add **`.inspector`** for supplementary panels (settings, metadata, tools) instead of a third custom column.
- Use **size classes** and `horizontalSizeClass` to adapt compact vs regular layouts.
- **`ViewThatFits`** when a row may need to collapse to a column on narrow widths.

```swift
NavigationSplitView {
    List(selection: $selection) { /* sidebar */ }
} detail: {
    DetailView(item: selection)
        .inspector(isPresented: $showInspector) {
            InspectorPanel()
        }
}
```

### Settings and forms
- **`Form`** for settings screens and data entry.
- Nest **`GroupBox`** inside `Form` or other `GroupBox` views for logical sections — the system alternates backgrounds per nesting level automatically.
- **`DisclosureGroup`** for expandable settings sections.
- **`LabeledContent`** for label/value rows (settings detail, read-only info).

## Visual grouping

Use Apple's grouping primitives — they carry correct spacing, materials, and accessibility:

```swift
GroupBox("Account") {
    LabeledContent("Username") { Text(user.name) }
    LabeledContent("Plan") { Text(user.plan) }
}

DisclosureGroup("Advanced") {
    Toggle("Analytics", isOn: $analytics)
}
```

- **`ControlGroup`** for related actions (media transport, toolbar-like button clusters).
- **`OutlineGroup`** for hierarchical tree data in lists.
- **`Label`** everywhere icons accompany text (lists, buttons, menus).

## Buttons and controls

Apply styles **once** at a container or app root; do not wrap `Button` in custom `MyButton` types.

```swift
// App root
ContentView()
    .tint(.teal)
    .buttonStyle(.borderedProminent)

// Destructive actions
Button(role: .destructive) { delete() } label: {
    Label("Delete", systemImage: "trash")
}

// Secondary actions
Button("Cancel", role: .cancel) { dismiss() }
    .buttonStyle(.bordered)
```

- **Roles**: `.destructive` for delete/remove, `.cancel` for dismissive actions.
- **Prominence**: `.borderedProminent` for primary CTA; `.bordered` or `.borderless` for secondary.
- **`Stepper`**, **`Gauge`**, **`Picker`**, **`Toggle`**, **`Slider`** — use as-is; apply `.pickerStyle(.segmented)` etc. at the group level.
- **`ShareLink`** for sharing URLs, text, or images — not `UIActivityViewController` wrappers.

## Colors, materials, and typography

- Use **semantic styles**: `.foregroundStyle(.primary)`, `.foregroundStyle(.secondary)`, `.tint(.mint)`.
- Use **system palette** names (`.teal`, `.mint`, `.indigo`, `.orange`) for accents — they adapt to light/dark and accessibility settings.
- Use **`foregroundStyle()`** instead of deprecated `foregroundColor()`.
- Support **Dynamic Type** — avoid fixed font sizes for body text; use `.font(.body)`, `.headline`, etc.
- **`MeshGradient`** for decorative backgrounds when a multi-point gradient is needed (iOS 18+); prefer materials (`.regularMaterial`) for functional surfaces.

## State, concurrency, and data

From project-wide Swift guidelines:

- **`@Observable`** for shared model state; `@State` to own it in a view; `@Bindable` for bindings to injected observables.
- **`@MainActor`** on types that drive UI; keep non-UI work off the main actor.
- **`async/await`** with strict concurrency; actors for shared mutable state.
- **Storage**: `UserDefaults` (simple prefs), Keychain (secrets), SwiftData (models), CloudKit (sync) — match the problem, don't invent file formats.
- **`Logger`** instead of `print()`; no forced unwraps (`!`).

## Animation and live content

- **`TimelineView`** for clocks, countdowns, or periodic refresh (weather, timers) — not `Timer` + `@State` polling.
- **`PhaseAnimator`** for repeating multi-phase animations (pulse, shimmer) — not manual animation loops.
- **`ScenePhase`** via `@Environment(\.scenePhase)` for foreground/background lifecycle in views.

## Accessibility and platform

- VoiceOver **labels and hints** on all interactive elements from the start.
- **Dark Mode** must work without separate color definitions when using semantic colors.
- Follow **Human Interface Guidelines** and App Store Review expectations.
- Add **Previews** to every view; use `#Preview` with varied size classes when layout adapts.

## Custom UI — only when necessary

Reach for custom views only after confirming no built-in fits:

| Need | Built-in first |
|------|----------------|
| Card / panel | `GroupBox` |
| Empty list | `ContentUnavailableView` |
| Expandable section | `DisclosureGroup` |
| Icon + title row | `Label` / `LabeledContent` |
| Tree list | `OutlineGroup` |
| Adaptive H/V layout | `ViewThatFits` |
| Custom arrangement | `Layout` protocol (not nested stacks with magic numbers) |
| Drawing / charts | `Canvas` (not `UIViewRepresentable` unless required) |
| Map | SwiftUI `Map` + `MapKit` |
| Multi-date selection | `MultiDatePicker` |
| Clipboard paste | `PasteButton` |
| Inline rename | `RenameButton` |
| Per-corner radius | `UnevenRoundedRectangle` |

Full catalog with usage notes: [built-in-components.md](built-in-components.md).

## Styling system components

- Set **`.buttonStyle`**, **`.tint`**, **`.toggleStyle`**, **`.pickerStyle`** on `WindowGroup` or screen root — styles propagate like environment values.
- Extend built-in styles with `Button(configuration)` / style-configuration initializers instead of per-button modifier stacks.
- **Nested `GroupBox` does not inherit a custom `.groupBoxStyle`** from its parent — reapply inside the style's `makeBody` or on each nested box. Prefer the default automatic style unless branding requires custom.
- **Sheets** may not inherit styles from the presenter — reapply styles on sheet content when needed.

Details: [styling.md](styling.md).

## Code quality checklist

Before finishing UI work:

- [ ] No custom card/button when `GroupBox` / `.borderedProminent` suffices
- [ ] No hard-coded RGB/hex colors for standard UI
- [ ] Navigation uses `NavigationStack` or `NavigationSplitView` (not legacy `NavigationView`)
- [ ] Empty states use `ContentUnavailableView`
- [ ] Icons are SF Symbols with appropriate rendering mode
- [ ] Forms and settings use `Form` + `LabeledContent` / `DisclosureGroup`
- [ ] Primary actions use `.borderedProminent`; destructive use `role: .destructive`
- [ ] Styles applied at root, not duplicated on every control
- [ ] Previews present; Dynamic Type and Dark Mode spot-checked
- [ ] Accessibility labels set on custom-labeled controls

## View structure

This skill does not cover refactoring large view bodies. When a screen grows beyond a short, scannable `body`:

- Extract rows, sections, and states into dedicated `View` structs — not extension computed properties
- Prefer `List` / `GroupBox` for extracted pieces instead of custom card modifiers
- See **`swiftui-view-composition`** for the full extraction workflow, decision guide, and refactor patterns

## Swift and project conventions

- One type per file; semantic folder grouping (feature folders, not `Views/` / `ViewModels/` splits).
- `// MARK: -` sections; protocol conformance in extensions.
- Swift Testing over XCTest for new tests; meaningful business-logic coverage.
- Remove stale code after refactors; match patterns already in the project.
- Do not add documentation files unless the user asks.
