# Indexing details

Portable patterns distilled from shipping a notes/journal vault with Core Spotlight.

## Item shape

| Attribute | Role |
|-----------|------|
| `uniqueIdentifier` | Stable app ID (path, UUID, etc.). Must map 1:1 back to a model object. |
| `domainIdentifier` | App-defined bucket (e.g. `app.notes`). Use for bulk delete by domain if needed. |
| `title` | Display title |
| `textContent` | Full plain-text body (+ optional date prefix for NL date queries) |
| `contentDescription` | Short snippet for result rows |
| `contentCreationDate` | Semantic document date when relevant |
| `contentModificationDate` | File/edit time for freshness |
| `keywords` | Extra tokens: tags, folder/journal name, date spellings |

Use `CSSearchableItemAttributeSet(contentType:)` appropriate to the content (often `.text` / `.content`).

## Date-aware keywords

Users ask “what did I write in July?” without exact tokens in the body. Index both:

1. **Keywords** — ISO `yyyy-MM-dd`, year, localized month name, “Month Year”, long date string.
2. **Text prefix** — a short leading sentence in `textContent` that repeats the human date and ISO day.

Keep this generation pure/deterministic so the reindex extension and the app build identical items.

## Incremental sync (app process)

Typical actor/service loop on library snapshot change:

1. Diff current IDs vs last-indexed IDs → `deleteSearchableItems(withIdentifiers:)` for removals.
2. For each item, skip if stored modification date equals snapshot modification date.
3. Build `CSSearchableItem`; set `isUpdate = true` when the ID was already indexed.
4. `indexSearchableItems(_:)`.
5. On failure, clear in-memory “indexed” marks for those IDs so the next pass retries.
6. Publish progress `(indexedCount, totalCount, isIndexing)` for UI.

Do not block vault load on Spotlight errors.

## Reindex extension

- Target: app extension, `NSExtensionPointIdentifier` = `com.apple.spotlight.index`.
- Principal class subclasses `CSIndexExtensionRequestHandler`.
- Implement:
  - `reindexAllSearchableItemsWithAcknowledgementHandler`
  - `reindexSearchableItemsWithIdentifiers(_:acknowledgementHandler:)`
- Always invoke the acknowledgement handler (success or empty/failure).
- Completion handlers from `indexSearchableItems` are not `@Sendable`; wrap the acknowledgement in a small `@unchecked Sendable` holder if you hop queues.
- Extension must resolve the same content store as the app (App Group + security-scoped bookmarks are common).

## Testing

- Unit-test item builders: identifier, domain, title, `contentCreationDate`, keyword set.
- Unit-test mappers: unknown IDs rejected; missing attributes fall back sensibly.
- Manual: install, add/edit/delete content, confirm system Spotlight and in-app search stay aligned after reindex prompts.
