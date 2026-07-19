# Query and Ask orchestration

## Mode selection

| Condition | Default mode |
|-----------|----------------|
| `SystemLanguageModel` available (iOS 26+) | **Ask** |
| Otherwise | **Search** (keyword / Spotlight only) |

Keep Search available even when Ask is supported — users may want exact lookup without summarization.

## In-app Spotlight query

```swift
CSUserQuery.prepare() // once per process

let context = CSUserQueryContext()
context.fetchAttributes = [
  "title", "textContent", "contentDescription",
  "contentCreationDate", "contentModificationDate"
]
context.enableRankedResults = true

let query = CSUserQuery(userQueryString: string, userQueryContext: context)
for try await response in query.responses {
  // map .item → app result; filter unknown IDs
}
```

Always filter with a live `knownPaths` / `isKnownNote` predicate. The index can contain deleted or foreign IDs.

## Fallback ladder (Search and Ask grounding)

When Spotlight returns no usable hits:

1. **Date parse** over local metadata (relative phrases, month/year, ISO days) → filter library by day → optional content keyword within that set.
2. **Keyword scan** of titles/bodies on disk (or cached plain text).
3. Show a short **fallback label** in the UI (“Showing notes from matching dates.” / “Showing keyword matches…”) so users know results aren’t ranked Spotlight hits.

Empty library vs empty index vs no match are different copy problems — mention indexing progress when the index is incomplete.

## Ask tier A — SpotlightSearchTool (iOS 27+ / new SDK)

When the SDK exposes Foundation Models Spotlight tools:

1. Configure `CoreSpotlightSource` with the same fetch attributes you map in Search.
2. Build `SpotlightSearchTool.Configuration` (sources + guide; keep the guide focused).
3. `LanguageModelSession(tools: [tool], instructions: trustedShortInstructions)`.
4. Concurrently consume `tool.searchResults` → map items → `onResultsUpdate` so the notes list fills **while** the model still works.
5. `session.respond(to: userPrompt)` → trim → Summary string.
6. If the tool yielded nothing, run the same fallback ladder as Search, then summarize if anything appears.

Gate with both compiler and OS checks so CI on older Xcode still compiles:

```swift
#if compiler(>=6.4)
if #available(iOS 27, *) {
  // SpotlightSearchTool path
}
#endif
```

(Adjust the compiler version to whatever first shipped the API you need.)

## Ask tier B — search-then-summarize (iOS 26+)

1. Run the shared Search pipeline (Spotlight → fallbacks).
2. Call `onResultsUpdate` immediately.
3. If no results, return a fixed “couldn’t find notes / indexing may be in progress” summary — **don’t** call the model with an empty context.
4. Otherwise build a compact prompt: numbered `title — long date (ISO)` + snippet lines.
5. Fresh `LanguageModelSession(instructions:)` + single `respond(to:)`.

Instructions should describe content layout and dating so the model interprets hits correctly. One concrete task: summarize relation to the question.

## Progressive UI contract

Outcome type (conceptually):

- `summary: String?` — nil while generating
- `results: [Hit]` — may update multiple times
- `fallbackLabel: String?`
- `isGeneratingSummary: Bool`

List behavior for Ask:

- As soon as Ask starts, show a **Summary** section with several lines of dummy copy and `.redacted(reason: .placeholder)`.
- Show **Notes** as soon as the first `onResultsUpdate` arrives (even while summary is still generating).
- Replace the placeholder with markdown-rendered summary text when ready.

### Markdown summaries

Models often emit `**bold**`. Render with:

```swift
AttributedString(
  markdown: text,
  options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
)
```

Fall back to plain `AttributedString(text)` if parsing fails. Prefer inline-only so a chatty summary doesn’t become a heading stack inside a `List` section.

## Demo / screenshot mode

For UI tests and App Store shots, seed `query`, `summary`, and `results` without invoking the model. Force Ask mode when the scene requires the Summary chrome.
