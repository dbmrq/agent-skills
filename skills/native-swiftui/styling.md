# Native SwiftUI styling

Use SwiftUI's style APIs so controls look consistent and propagate from containers — the same model as `.font()` and `.tint()`.

## Apply styles at the root

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.teal)
                .buttonStyle(.borderedProminent)
                .toggleStyle(.switch)
                .pickerStyle(.segmented)
        }
    }
}
```

Styles on a parent flow to matching child controls — set once per screen or app, not per button.

## Built-in button styles

| Style | Use for |
|-------|---------|
| `.borderedProminent` | Primary call to action |
| `.bordered` | Secondary actions |
| `.borderless` | Tertiary / inline actions |
| `.plain` | Minimal chrome in lists |

Combine with `ButtonRole`:

```swift
Button(role: .destructive) { } label: { Label("Delete", systemImage: "trash") }
Button("Cancel", role: .cancel) { }
```

**Do not** create wrapper views like `MyButton` that hard-code padding and colors — use `.buttonStyle` instead.

## Composing styles (extending, not replacing)

To tweak a built-in style, create a style that wraps the current style via the configuration initializer:

```swift
struct OutlinedProminentStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .buttonBorderShape(.roundedRectangle(radius: 4))
            .fontWeight(.semibold)
    }
}

// Order matters: modifier style BELOW base style in the chain
Button("Save") { }
    .buttonStyle(OutlinedProminentStyle())
    .buttonStyle(.borderedProminent)
```

Styles compose like a stack — the style **closer to the button** wraps the style above it. Wrong order silently drops the modifier style.

Prefer parameterized composition for readability:

```swift
.buttonStyle(.borderedProminent)  // base at root
// Per-control override only when needed:
.buttonStyle(.bordered)           // on secondary buttons in the same hierarchy
```

## GroupBox styling

- Default automatic style **alternates background** for nested `GroupBox` levels — use nested boxes for sub-sections without custom colors.
- Custom `.groupBoxStyle` on a parent **does not propagate** to nested `GroupBox` children (unlike `.font` or `.tint`).
- To style nested boxes consistently, either:
  - Reapply `.groupBoxStyle` on each nested `GroupBox`, or
  - Reapply `.groupBoxStyle(self)` inside the custom style's `makeBody`.

**Prefer the default GroupBox style** unless product branding requires a custom outline or card style.

## Scoped style modifiers

Apply a modifier only to one control type in a subtree — e.g. button label layout:

```swift
ContentView()
    .buttonStyle(.labelStyle(.trailing))
    .buttonStyle(.bordered)
```

To override on a single button, reapply the full style chain on that button (partial override won't work).

## Disabled state in custom styles

`ButtonStyle.Configuration` has no `isDisabled` flag. Read `@Environment(\.isEnabled)` inside `makeBody`:

```swift
@Environment(\.isEnabled) private var isEnabled

.opacity(isEnabled ? 1 : 0.5)
.saturation(isEnabled ? 1 : 0)
```

## Sheets and modal propagation

Styles set on the presenter may **not** reach content inside `.sheet`, `.fullScreenCover`, or `.popover`. Reapply styles on the sheet's root view when controls look unstyled.

Environment values have similar limitations in some iOS versions inside modals.

## Dynamic and conditional styles

Pick styles based on context inside `makeBody`:

```swift
struct AdaptiveButtonStyle: PrimitiveButtonStyle {
    @Environment(\.horizontalSizeClass) var sizeClass

    func makeBody(configuration: Configuration) -> some View {
        let button = Button(configuration)
        if sizeClass == .compact {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}
```

For toggles, use conditional style helpers when a single checkbox vs switch is context-dependent.

## Custom components — styling API pattern

When a truly custom control is unavoidable, mirror Apple's pattern:

1. `XxxStyle` protocol with `makeBody(configuration:)`
2. `XxxStyleConfiguration` holding inputs (type-erased label via wrapper)
3. `@Environment(\.xxxStyle)` with default style
4. `extension View { func xxxStyle(_:) }` modifier

Styles for custom views should use an intermediate `resolve(configuration:)` view so `@Environment` works inside styles (concrete generic style type required).

Only build this machinery when no built-in control fits.

## Anti-patterns

| Anti-pattern | Native alternative |
|--------------|-------------------|
| Per-button padding/background modifiers | `.buttonStyle` at container |
| `MyPrimaryButton` wrapper struct | `.borderedProminent` + `.tint` |
| Custom card `ZStack` + shadow | `GroupBox` |
| Copy-paste style modifiers across screens | Root `.theme` or style chain on `WindowGroup` |
| `foregroundColor(.blue)` | `.foregroundStyle(.tint)` or `.tint(.blue)` |
| Hex colors for standard chrome | Semantic / system colors |
