# Built-in SwiftUI components catalog

Prefer these over custom implementations. Check minimum deployment target before using newer APIs.

## Time and lifecycle

### TimelineView
Live-updating content driven by system time.

```swift
// Clock
TimelineView(.animation) { context in
    Text(context.date, style: .time)
}

// Countdown (1s ticks)
TimelineView(.periodic(from: .now, by: 1)) { context in
    let remaining = max(endDate.timeIntervalSince(context.date), 0)
    Text("\(Int(remaining))s left")
}

// Periodic data refresh (e.g. every 60s)
TimelineView(.periodic(from: .now, by: 60)) { context in
    WeatherView(lastUpdated: context.date)
}
```

### ScenePhase
React to app lifecycle from any view:

```swift
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .active: resumeWork()
    case .background: pauseWork()
  default: break
    }
}
```

## Grouping and structure

### GroupBox
Default choice for card-like grouped content with an optional title. Nested boxes get distinct system backgrounds.

```swift
GroupBox("User Info") {
    VStack(alignment: .leading) {
        Text("Name: \(name)")
        Text("Role: \(role)")
    }
}
```

### DisclosureGroup
Expandable sections — settings, optional fields, FAQ items.

```swift
DisclosureGroup("More Settings") {
    Toggle("Dark Mode", isOn: $darkMode)
}
```

### ControlGroup
Clusters related buttons (media controls, formatting tools).

```swift
ControlGroup {
    Button { rewind() } label: { Image(systemName: "backward.fill") }
    Button { play() } label: { Image(systemName: "play.fill") }
    Button { forward() } label: { Image(systemName: "forward.fill") }
}
```

### LabeledContent
Standard label + value rows in forms and detail screens.

```swift
LabeledContent("Username") {
    Text("jane@example.com")
}
```

### Label
Icon + text with consistent spacing and accessibility.

```swift
Label("Cart", systemImage: "cart")
```

### OutlineGroup
Hierarchical tree data in lists.

```swift
OutlineGroup(animals, children: \.children) { animal in
    Text(animal.name)
}
```

## Content and feedback

### ContentUnavailableView
Native empty states — search results, empty inboxes, missing data.

```swift
ContentUnavailableView(
    "No Messages",
    systemImage: "bubble.left.and.bubble.right",
    description: Text("Start a conversation to see messages here.")
)
```

### Gauge
Progress and measurements (iOS 16+).

```swift
Gauge(value: progress) {
    Text("Loading")
}
```

## Input and selection

### ColorPicker
System color picker — do not build a custom hue wheel.

```swift
ColorPicker("Accent", selection: $accentColor)
```

### Stepper
Numeric step control with optional range.

```swift
Stepper("Quantity: \(count)", value: $count, in: 0...10)
```

### MultiDatePicker
Multi-date calendar selection.

```swift
@State private var dates: Set<DateComponents> = []

MultiDatePicker("Travel dates", selection: $dates)
```

### PasteButton
Native paste from clipboard.

```swift
PasteButton(payloadType: String.self) { strings in
    pastedText = strings.joined(separator: "\n")
}
.buttonStyle(.borderedProminent)
```

### RenameButton
Inline rename affordance (lists, editable titles).

```swift
HStack {
    Text(title)
    Spacer()
    RenameButton().renameAction { startRename() }
}
```

## Sharing and maps

### ShareLink
Native share sheet for URLs, text, images.

```swift
ShareLink(item: url) {
    Label("Share", systemImage: "square.and.arrow.up")
}
```

### Map
Interactive maps with annotations (MapKit).

```swift
Map(position: $position) {
    Annotation("Location", coordinate: coord) {
        Image(systemName: "mappin.circle.fill")
    }
}
```

## Layout and drawing

### ViewThatFits
Pick the first child that fits — adaptive toolbar/header layouts (iOS 16+).

```swift
ViewThatFits {
    HStack { title; icon }
    VStack { title; icon }
}
```

### Layout protocol
Custom layouts when stacks are insufficient — prefer over manual offset math.

### Canvas
2D drawing for charts, graphs, simple games.

```swift
Canvas { context, size in
    context.fill(Path(ellipseIn: CGRect(origin: .zero, size: size)), with: .color(.blue))
}
```

### UnevenRoundedRectangle
Per-corner radii without custom `Shape` types.

```swift
UnevenRoundedRectangle(
    cornerRadii: RectangleCornerRadii(
        topLeading: 30, bottomLeading: 50,
        bottomTrailing: 10, topTrailing: 5
    )
)
.fill(.pink.gradient)
```

## Animation and visuals

### PhaseAnimator
Multi-phase repeating animations without manual loops.

```swift
PhaseAnimator(["idle", "pulsing"]) { phase in
    Circle()
        .scaleEffect(phase == "idle" ? 0.4 : 0.8)
        .opacity(phase == "idle" ? 1.0 : 0.7)
}
```

### MeshGradient
Multi-point gradient backgrounds (iOS 18+).

```swift
MeshGradient(
    width: 2, height: 2,
    points: [[0, 0], [1, 0], [0, 1], [1, 1]],
    colors: [.blue, .purple, .pink, .orange]
)
```

## Observation (iOS 17+)

Prefer `@Observable` over `ObservableObject`:

```swift
@Observable class Counter { var count = 0 }

struct CounterView: View {
    @State private var counter = Counter()
    var body: some View {
        Button("Count: \(counter.count)") { counter.count += 1 }
    }
}
```

## Styleable built-in views

These support `.xxxStyle()` modifiers — customize via styles, not one-off modifier stacks:

`Button`, `Toggle`, `Picker`, `DatePicker`, `Gauge`, `ProgressView`, `Label`, `LabeledContent`, `DisclosureGroup`, `ControlGroup`, `GroupBox`, `Form`

See [styling.md](styling.md) for composition and propagation rules.
