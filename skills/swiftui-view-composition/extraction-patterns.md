# Extraction patterns

Concrete patterns for breaking down SwiftUI screens. Pair with `native-swiftui` for component choices.

## Pattern: list screen

```swift
// Screen — orchestrates only
struct ArticleListView: View {
    let articles: [Article]

    var body: some View {
        Group {
            if articles.isEmpty {
                ContentUnavailableView("No Articles", systemImage: "doc.text")
            } else {
                List(articles) { ArticleRow(article: $0) }
            }
        }
        .navigationTitle("Articles")
    }
}
```

Extract: `ArticleRow`, empty state inline or `ArticleListEmptyView` if complex.

## Pattern: settings section

```swift
struct SettingsView: View {
  @State private var notifications = true

  var body: some View {
    Form {
      NotificationsSection(isOn: $notifications)
      AccountSection()
    }
    .navigationTitle("Settings")
  }
}

struct NotificationsSection: View {
  @Binding var isOn: Bool

  var body: some View {
    Section("Notifications") {
      Toggle("Push alerts", isOn: $isOn)
    }
  }
}
```

Prefer `Form` + `Section` + `DisclosureGroup` over custom grouped cards.

## Pattern: detail header

Extract when header has avatar, metadata, and actions:

```swift
struct ProfileHeader: View {
  let user: User
  let onEdit: () -> Void

  var body: some View {
    HStack {
      // avatar + labels
      Spacer()
      Button("Edit", action: onEdit)
        .buttonStyle(.bordered)
    }
  }
}
```

Screen-specific API (`onEdit`) is correct — do not genericize prematurely.

## Pattern: repeated modifier chain → ViewModifier

**Trigger:** same 3+ modifiers copied across files.

```swift
// Before — duplicated
Text("Title")
  .font(.headline)
  .foregroundStyle(.primary)
  .accessibilityAddTraits(.isHeader)

// After
extension View {
  func screenTitle() -> some View {
    font(.headline)
      .foregroundStyle(.primary)
      .accessibilityAddTraits(.isHeader)
  }
}
```

Prefer SwiftUI's built-in style APIs (`.buttonStyle`, `.tint`) at the root before inventing modifiers.

## Pattern: section header extension

```swift
extension View {
  func underSectionHeader(_ title: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.title3)
        .bold()
        .accessibilityAddTraits(.isHeader)
      self
    }
  }
}
```

Alternative: `Section` inside `List`/`Form` when the content is list-driven.

## Pattern: loading overlay

```swift
struct LoadingOverlay<Content: View>: View {
  let isLoading: Bool
  @ViewBuilder var content: () -> Content

  var body: some View {
    content()
      .overlay {
        if isLoading { ProgressView().controlSize(.large) }
      }
      .allowsHitTesting(!isLoading)
  }
}
```

Generic container — justified when used across multiple features.

## Anti-patterns

| Avoid | Prefer |
|-------|--------|
| `extension MyView { var row: some View }` for complex rows | `struct MyRow: View` |
| `MyButton` wrapper with hard-coded colors | `.buttonStyle` at root (`native-swiftui`) |
| `cardStyle()` on every row | `List`, `GroupBox`, or `.listRowBackground` |
| God view with 300-line `body` | Screen + 3–6 child views |
| Generic `ConfigurableCard(title:subtitle:icon:action:style:)` with 12 parameters | Feature-local `ArticleRow` |

## When @ViewBuilder functions are acceptable

Small, private, single-use helpers with no reuse and few subviews:

```swift
private func toolbarContent() -> some View {
  HStack {
    Spacer()
    EditButton()
  }
}
```

Do not use for `ForEach` rows, stateful sections, or anything needing previews.
