---
name: swiftui-view-composition
description: >-
  Structure and refactor SwiftUI views for readability, reuse, and maintainability
  by extracting dedicated View structs, ViewModifiers, and layout helpers instead of
  bloated bodies or extension dumping grounds. Use when breaking down large views,
  improving screen clarity, creating reusable components, or reviewing SwiftUI
  architecture and view organization.
---

# SwiftUI View Composition

Structure SwiftUI screens so `body` reads like a high-level overview — not an implementation dump. The goal is **clarity and reusability**, not minimizing line count.

**Skill split:**
- **`swiftui-view-composition`** (this skill) — *how* to structure and refactor views
- **`native-swiftui`** — *what* Apple components and system styles to use
- **`swiftui-project-structure`** — repo folders, packages, targets, MV vs Store layers
- **`swiftui-expert-skill`** — state, performance, concurrency ([avdlee/swiftui-agent-skill](https://github.com/avdlee/swiftui-agent-skill); install via `./scripts/install-all.sh`)

## Agent workflow

1. **Scan the view** — identify logical clusters (header, row, empty state, toolbar, section).
2. **Ask the reuse question** — *"Does this UI have a clear purpose and potential to be reused?"* (see [Decision guide](#decision-guide))
3. **Extract in order** — dedicated `View` → repeated styling as modifier → generic layout helper.
4. **Check native alternatives** — before custom card/row styling, consult `native-swiftui` (`GroupBox`, `List`, `LabeledContent`).
5. **Add previews** — each extracted view gets `#Preview` with its states.
6. **Leave `body` declarative** — screen view orchestrates; children render.

## The problem: growing view bodies

Large `body` properties with nested stacks and inline styling are hard to scan, test, and evolve. Adding empty states, loading, and actions makes it worse.

**First step when refactoring:** identify *subjects* — self-contained UI clusters that could become their own unit.

## Anti-pattern: extensions and computed properties

Moving `body` chunks into `extension` computed properties or `@ViewBuilder` functions **only moves code around**. It does not improve reusability or maintainability, and the file often grows longer.

```swift
// Avoid as the primary refactor — not reusable, no isolated previews
extension ArticleListView {
    var header: some View { Text("Articles").font(.largeTitle).bold() }

    func articleRow(for article: Article) -> some View {
        HStack { /* 20 lines of layout */ }
    }
}
```

**When computed properties are OK:** tiny, single-use sections with no reuse potential and no performance concern — keep them private and simple.

**Prefer separate `struct` views** for anything with its own concern, multiple states, or reuse potential. Separate structs also let SwiftUI skip `body` re-evaluation when inputs are unchanged (see `swiftui-expert-skill` view-structure guidance).

## Cross-file extensions

Splitting a **type** across files (e.g. `NoteStore+Notes.swift` for SwiftLint length limits) is fine for stores/models. That is not the same as dumping `body` into extension computed properties.

**Access control:** `private` and `private(set)` are **file-private**. Extensions in *other* files cannot read or assign those members — you get “setter is inaccessible” / “inaccessible due to private”. Widen anything shared across those files to **`internal`** (omit the keyword). Keep `private` only for helpers that stay in the defining file.

```swift
// NoteStore.swift — OK for cross-file extensions
var snapshot: VaultSnapshot   // internal
var isLoaded = false

// NoteStore.swift — NOT OK if NoteStore+Loading.swift assigns it
private(set) var isLoaded = false
```

After splits: `xcodegen generate` (if used), build, then `./scripts/check.sh` and `./scripts/deadcode.sh` (see **ios-quality-gate**).

## Three extraction techniques

### 1. Extract dedicated SwiftUI views

Give each logical UI unit its own `View` struct with explicit inputs:

```swift
struct ArticleRow: View {
    let article: Article

    var body: some View {
        LabeledContent(article.title) {
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
    }
}

struct ArticleListView: View {
    let articles: [Article]

    var body: some View {
        List(articles) { article in
            ArticleRow(article: article)
        }
        .navigationTitle("Articles")
    }
}
```

Benefits:
- Screen `body` reads as an outline
- Single responsibility per file
- States and previews live in one place
- Reusable on other screens

### 2. Create reusable view modifiers

When the **same modifier chain** appears on multiple views, extract it — but prefer **system styles** first (`native-swiftui`).

```swift
// Only when system components don't fit and the pattern repeats app-wide
struct ElevatedSurfaceStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func elevatedSurface() -> some View {
        modifier(ElevatedSurfaceStyle())
    }
}
```

**Before creating `cardStyle()`:** check whether `GroupBox`, `List` + `.listStyle`, or `.buttonStyle` already solve it. Custom card modifiers are a last resort for branded design tokens, not default row styling.

**Detection workflow:** search the codebase for repeated modifier combinations → replace with one modifier → update all call sites.

### 3. Build generic view extensions

For repeated **layout patterns** (not full components), use `@ViewBuilder` extensions:

```swift
extension View {
    func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .bold()
            self
        }
    }
}

// Usage
VStack {
    ForEach(articles) { ArticleRow(article: $0) }
}
.sectionHeader("Articles")
```

Trade-off: less explicit than a `SectionHeader` view, but reduces indentation. Use when the wrapper is purely structural and unlikely to need its own state or previews.

## Decision guide

Ask before extracting:

> *"Does this piece of UI have a clear purpose and potential to be reused?"*

| Answer | Action |
|--------|--------|
| **Yes** — distinct concern, appears elsewhere, or needs isolated previews | New `View` struct (or `ViewModifier` for repeated styling) |
| **Maybe** — used once now but likely again | Extract `View`; move to shared folder when second use appears |
| **No** — one-off, trivial, tightly coupled to parent | Keep inline or use a small private computed property |

### Extraction priority

1. **Rows and cells** (`ArticleRow`, `SettingsToggleRow`)
2. **Empty / loading / error states** (often `ContentUnavailableView` — see `native-swiftui`)
3. **Section headers and toolbars**
4. **Repeated styling** → modifier (after checking system alternatives)
5. **Layout shells** → generic extension

### Rule of three (abstraction guard)

Promote a view to a **shared, generic primitive** only after **three concrete uses** with the same behavior. Before that, keep it feature-local — screen-specific APIs are fine; do not invent a 12-parameter “configurable” view to force reuse.

## Configuration objects (avoid long initializers)

When a view would take roughly **four or more** related parameters — especially mixed data, bindings, and action closures — wrap them in a dedicated configuration (or actions) struct and pass that instead of a flat parameter list.

```swift
// Avoid
struct ItemRow: View {
    let title: String
    let subtitle: String?
    let isCompact: Bool
    let onTitleChange: (String) -> Void
    let onDelete: () -> Void
    let onIndent: () -> Void
    // …
}

// Prefer
struct ItemRowConfiguration {
    var title: String
    var subtitle: String?
    var actions: ItemRowActions
}

struct ItemRow: View {
    let configuration: ItemRowConfiguration
}
```

Keep configuration types **feature-local** and one primary type per file. Prefer small, named bags (`…Configuration`, `…Actions`) over generic “options” dictionaries.

## Display-mode sibling views

Do **not** branch compact/comfortable (or similar display modes) throughout a single `body`. Create separate views for each mode and toggle at the parent; share metrics/constants in a layout/chrome enum so mode switches stay visually stable.

```swift
// Avoid
var body: some View {
    if isCompact { /* compact layout */ } else { /* comfortable layout */ }
}

// Prefer
var body: some View {
    if isCompact {
        CompactItemRowBody(configuration: configuration)
    } else {
        ComfortableItemRowBody(configuration: configuration)
    }
}
```

## Refactor walkthrough

**Before** — monolithic list with inline row styling:

```swift
struct ArticleListView: View {
    let articles: [Article]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Articles").font(.largeTitle).bold()
            ForEach(articles, id: \.url) { article in
                HStack {
                    VStack(alignment: .leading) {
                        Text(article.title).font(.headline)
                        Text(article.url.absoluteString)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
    }
}
```

**After** — composed, native-aligned:

```swift
struct ArticleListView: View {
    let articles: [Article]

    var body: some View {
        List(articles) { article in
            ArticleRow(article: article)
        }
        .navigationTitle("Articles")
    }
}

struct ArticleRow: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading) {
            Text(article.title).font(.headline)
            Text(article.url.absoluteString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Row") {
    ArticleRow(article: Article(title: "SwiftUI", url: URL(string: "https://example.com")!))
}
```

Changes: extracted row, `List` instead of manual card stacks, navigation title instead of inline header (or use `.sectionHeader` if staying in `VStack`).

More patterns: [extraction-patterns.md](extraction-patterns.md).

## File and folder conventions

- **One primary type per file**; name the file after the type (`ArticleRow.swift`, `ItemRowActions.swift`).
- **Co-locate by feature** — `Articles/ArticleListView.swift`, `Articles/ArticleRow.swift` — not global `Views/` dumps. For repo-level layout (packages, targets, `Navigation/`, when to add a Store), see **`swiftui-project-structure`**.
- Within a feature, use **semantic subfolders** when the file count grows (e.g. `Editor/Row/`, `Editor/Chrome/`, `Editor/Layout/`) so related types stay findable.
- **Shared primitives** — only after rule-of-three; e.g. `DesignSystem/ElevatedSurface.swift` or a small Swift package.
- **`// MARK: -`** for properties, body, helpers; protocol conformance in extensions.

## Screen vs component views

| Type | Role | API shape |
|------|------|-----------|
| **Screen / orchestrator** | Wires navigation, state, and child views | Owns `@State`, fetches data, composes children |
| **Component** | Renders one UI unit | `let` inputs; callbacks for actions (`onTap`, `onDelete`) |
| **Primitive** | App-wide design atom | Minimal, stateless, generic |

Do not force screen-specific orchestrators into generic shared components — give them a name and a rich, local API.

## Previews

Every extracted view gets previews for its meaningful states:

```swift
#Preview("Default") { ArticleRow(article: .sample) }
#Preview("Long title") { ArticleRow(article: .longTitleSample) }
#Preview("Empty list") { ArticleListView(articles: []) }
```

Use `@Previewable` for dynamic preview state when needed.

## Checklist

Before finishing a refactor:

- [ ] Screen `body` is a short, readable composition
- [ ] Reusable pieces are `struct` views, not extension computed properties
- [ ] Repeated styling extracted to modifier — or replaced with system styles (`native-swiftui`)
- [ ] No premature generic abstractions (rule of three)
- [ ] Previews cover main states per extracted view
- [ ] Files grouped by feature (and semantic subfolders when needed), one primary type per file
- [ ] Long initializers collapsed into configuration/actions objects
- [ ] Display modes use sibling views + shared constants, not heavy `if isCompact` bodies
- [ ] Business logic not embedded in `body` — delegate to model methods or `.task`

## Related skills

- **`native-swiftui`** — prefer `GroupBox`, `List`, system button styles over custom cards
- **`swiftui-project-structure`** — feature folders, SPM packages, app/scene wiring, architecture layers
- **`swiftui-expert-skill`** — property wrappers, diffing performance, list identity ([avdlee/swiftui-agent-skill](https://github.com/avdlee/swiftui-agent-skill))
- Source inspiration: [SwiftUI Architecture — Antoine van der Lee](https://www.avanderlee.com/swiftui/swiftui-architecture-structure-views-for-reusability-and-clarity/)
