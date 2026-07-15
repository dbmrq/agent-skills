# Prompting and operations notes

Use this file for the details agents are likely to forget while implementing or debugging a feature.

## Session shape

- **Single-turn task:** create a fresh `LanguageModelSession` per request.
- **Multi-turn interaction:** reuse the same session only when transcript carry-forward is desired product behavior.
- **Concurrency rule:** one session can process only **one request at a time**. Serialize requests or check `isResponding`.
- `prewarm(promptPrefix:)` is optional latency optimization, not a functional requirement.

## Prompting rules for the on-device model

- Prefer **one concrete task per prompt**.
- Use **direct imperative phrasing**: “Summarize…”, “Extract…”, “Classify…”.
- Keep prompts short; move conditionals and branching into app logic.
- Ask for shorter output in the prompt itself (“in 3 bullets”, “in one sentence”) before using `maximumResponseTokens`.
- Instructions outrank prompts; only put **trusted** content there.

If a prompt contains multiple conditional branches, compute the relevant branch in Swift and inject only that branch. Don’t hand the model a giant `if X do Y, if A do B…` prompt unless you have tested that it behaves reliably.

## Guided generation

Use `respond(to:generating:)` with `@Generable` types for structured results such as:

- extraction output
- summaries with named fields
- classification results
- settings or content suggestions
- tool arguments

### Rules that matter

- Do **not** ask for JSON text and parse it manually when `@Generable` will do.
- Keep `@Guide` descriptions short; clear property names are often enough.
- Property order matters — fields are generated in declaration order.
- Use constraints like `.range`, `.minimumCount`, `.maximumCount` to reduce drift and wasted tokens.
- For runtime-only schemas, use `DynamicGenerationSchema` / `GenerationSchema`.

### Reasoning with structured output

If you need the model to “show its work”, give it a dedicated **first** reasoning field, then a separate answer field. This prevents reasoning text from leaking into the final answer structure.

### Schema injection

`includeSchemaInPrompt` / `ContextOptions(includeSchemaInPrompt:)` can improve quality in some cases, but it also consumes extra context. Use it only if testing shows a meaningful improvement.

## Tool calling

Reach for tools when the model needs:

- app-local or fresh data
- privileged framework access (Contacts, HealthKit, Vision tools, etc.)
- permission-gated actions or side effects

Avoid tools when the app already knows the data and can simply put it into the prompt.

### Tool rules

- Keep tool names, descriptions, and argument guides **short**.
- Prefer **3–5 tools max** per request.
- Make tool implementations concurrency-safe: tools may be called concurrently with themselves or other tools.
- Return compact outputs; verbose tool output burns context quickly.

### `toolCallingMode` trap

- `.allowed` — normal/default mode
- `.disallowed` — force a direct answer
- `.required` — use only if you define an exit condition

Non-obvious trap: if you set `.required` and never switch back to `.allowed` (or throw), the model can keep calling tools indefinitely.

Safe exits:

1. tool throws when it cannot continue, or
2. on 27+ Beta, a `DynamicProfile` flips `toolCallingMode` from `.required` to `.allowed` after the necessary call(s)

### Tool failures and transcript behavior

- Tool failures surface as `LanguageModelSession.ToolCallError`.
- The framework can roll the transcript back to a known-good state.
- If you need to inspect partial last-turn state during debugging, use `transcriptErrorHandlingPolicy(.preserveTranscript)` on a dynamic profile.
- Use `session.transcript` to inspect prompt → tool call → tool output → final response flow.

## Token and context budgeting

### What counts toward context

- instructions
- prompts
- responses
- `@Generable` schemas and guides
- tool definitions
- tool arguments and tool output
- transcript history
- reasoning text on reasoning-enabled 27+ paths

### Practical limits

- **On-device `SystemLanguageModel`: 4,096 tokens**
- **PCC: 32K tokens**

### Optimization rules

- Use `tokenCount(for:)` and `contextSize` during development, especially after adding large prompts or schemas.
- Optimize **prompts, instructions, schemas, and tool output** before using `maximumResponseTokens`.
- Keep `Generable` types minimal; remove unused fields before refining wording.
- For long tasks, split work across multiple sessions and chain summaries/results.

### Recovering from context overflow

When you hit `LanguageModelError.contextSizeExceeded(_)`:

1. create a fresh session
2. seed it with a condensed transcript or summary
3. retry the task

Cheap reset pattern: preserve the **first** transcript entry (often instructions) and the **last** entry (latest context), then create a new session from that condensed transcript.

## Prompt versioning

- Externalize prompts into string catalogs or separate text assets; don’t bury them across arbitrary view files.
- Gate prompt variants with `#available`, newest first.
- Record representative outputs for old vs new model versions before changing prompts.
- Re-test prompts when Apple notes improved instruction following or tool calling in Foundation Models updates.

## Canonical docs

- Generating content and performing tasks: <https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models>
- Prompting an on-device foundation model: <https://developer.apple.com/documentation/foundationmodels/prompting-an-on-device-foundation-model>
- Guided generation / `Generable`: <https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation>
- Tool calling: <https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling>
- Managing the context window: <https://developer.apple.com/documentation/foundationmodels/managing-the-context-window>
- Updating prompts for new model versions: <https://developer.apple.com/documentation/foundationmodels/updating-prompts-for-new-model-versions>