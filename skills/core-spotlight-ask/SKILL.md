---
name: core-spotlight-ask
description: >-
  Index app content in Core Spotlight and build on-device “Ask” search with
  Foundation Models (CSSearchableItem, CSUserQuery, SpotlightSearchTool,
  search-then-summarize fallbacks, indexing progress, progressive results).
  Use when adding Spotlight indexing, reindex extensions, keyword/date search,
  or Apple Intelligence Ask over local notes/documents in Swift/SwiftUI apps.
---

# Core Spotlight + Ask

Ship **local searchable content** with Core Spotlight, then optionally ground **Apple Intelligence Ask** in that index. Prefer Spotlight for discovery; use the language model only to summarize or answer against retrieved hits.

**Related skills:**
- **`apple-foundation-models`** — sessions, availability, prompting, tool-calling rules (not Spotlight-specific)
- **`native-swiftui`** — search UI, `ContentUnavailableView`, redacted placeholders
- **`swiftui-project-structure`** — split indexing vs search packages/targets

## Agent workflow

1. **Split ownership** — indexing (build/sync/delete items + reindex extension) separate from query/Ask UI.
2. **Choose stable IDs** — `uniqueIdentifier` must round-trip to an app model; use one `domainIdentifier` per content kind.
3. **Index for how users ask** — put titles, plain text, short snippets, modification dates, and **date/tag keywords** into attributes users will query.
4. **Sync incrementally** — index only changed items (`isUpdate`), delete removed IDs, report progress to the UI.
5. **Add a Spotlight index extension** — implement `CSIndexExtensionRequestHandler` for system-requested reindex.
6. **Query with `CSUserQuery`** — call `CSUserQuery.prepare()` once per process; request the `fetchAttributes` you need to map results.
7. **Filter stale hits** — drop Spotlight results whose IDs are unknown to the live vault/library.
8. **Fallback ladder** — if Spotlight returns nothing: date-aware local scan → keyword scan of on-disk content; label the fallback in UI.
9. **Gate Ask on the model** — default UX to Ask when `SystemLanguageModel` is available, else keyword Search.
10. **Orchestrate Ask in tiers** — iOS 27+ `SpotlightSearchTool` when available; else search-then-summarize with compact excerpts in the prompt (iOS 26+).
11. **Progressive UI** — stream note hits as they arrive; keep a Summary section with a redacted placeholder until the model finishes; render summary markdown with `AttributedString`.

## Hard-won rules

### Indexing

- Strip markup before indexing (`textContent` / `contentDescription` should be plain language).
- Prefixed date prose in `textContent` (“Date: 4 July 2026 (2026-07-04). …”) plus date **keywords** (ISO day, year, month name, “Month Year”) makes natural-language date asks work.
- Set `contentCreationDate` to the **semantic** document day when that matters more than file birth time (journals, diaries).
- Keep `contentDescription` short (~snippet length); put the full plain body in `textContent`.
- Track last-indexed modification times in memory (or durable store) so resync is cheap.
- Spotlight index/delete can fail on Simulator — don’t fail the whole library sync because of that.
- Reindex extension principal class: `CSIndexExtensionRequestHandler` subclass; extension point `com.apple.spotlight.index`. Always call the acknowledgement handler.
- Share App Group / bookmarks with the extension when content lives outside the app container.

### Query

- Map `uniqueIdentifier` → app reference; reject unknowns (`isKnownNote` / `knownPaths`).
- Prefer ranked `CSUserQuery` with explicit `fetchAttributes` (`title`, `textContent`, `contentDescription`, dates).
- Surface indexing progress while the index is incomplete (“Indexing… N of M”); empty Ask results may mean “still indexing,” not “no notes.”

### Ask / Foundation Models

- **Don’t** dump the whole library into the prompt. Retrieve first, then summarize.
- **iOS 27+ (when SDK has it):** `SpotlightSearchTool` + `LanguageModelSession(tools:)` with a short trusted instructions string; observe `tool.searchResults` to update the notes list **before** `session.respond` returns.
- **iOS 26 fallback:** run the same Spotlight/vault search the Search mode uses, `onResultsUpdate` immediately, then one-shot `LanguageModelSession` over numbered title/date/snippet excerpts.
- Wrap 27-only APIs in `#if compiler(>=…)` **and** `#available(iOS 27, *)` so older toolchains still compile.
- Ask instructions: one task (search + brief summary), mention how content is organized/dated, prefer plain language; models may emit light markdown — render it, don’t show raw `**`.
- Product states: model unavailable, indexing in progress, no hits, tool/search failure, Search-only fallback.

### UX

- Show Summary **while generating** (`.redacted(reason: .placeholder)` dummy lines), not only after the answer arrives.
- Parse summary with `AttributedString(markdown:options: .inlineOnlyPreservingWhitespace)` (or equivalent) so bold/italic display correctly.
- Debounce typing for Search; Ask usually runs on submit.
- Demo/screenshot seeds should set query + summary + results without waiting on the model.

## Shipping checklist

- [ ] Stable `uniqueIdentifier` + `domainIdentifier`
- [ ] Incremental sync + delete for removed items
- [ ] Spotlight index extension handles reindex-all and reindex-by-ID
- [ ] `CSUserQuery.prepare()` once; fetchAttributes cover mapping needs
- [ ] Stale-hit filter against live library IDs
- [ ] Fallback when Spotlight is empty (with user-visible label)
- [ ] Indexing progress exposed to search UI
- [ ] Ask gated on model availability; Search still works without AI
- [ ] Tiered Ask (Spotlight tool vs search-then-summarize)
- [ ] Progressive results + redacted Summary + markdown rendering

## Additional resources

- Attribute choices, incremental sync, reindex extension: [references/indexing.md](references/indexing.md)
- Query fallbacks, Ask tiers, progressive UI: [references/ask-and-query.md](references/ask-and-query.md)
- Core Spotlight: <https://developer.apple.com/documentation/corespotlight>
- Foundation Models tools: see **`apple-foundation-models`**
