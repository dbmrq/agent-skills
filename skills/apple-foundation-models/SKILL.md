---
name: apple-foundation-models
description: >-
  Integrate Apple Foundation Models into iOS apps — model selection,
  availability gates, prompting for the on-device model, guided generation,
  tool calling, Private Cloud Compute, token budgeting, locale handling, and
  model-version prompt updates. Use when building or reviewing Apple
  Intelligence / Foundation Models features in Swift or SwiftUI.
---

# Apple Foundation Models

Implement Apple Foundation Models with **availability-gated UI, short prompts, typed output, and explicit fallbacks**. Default to the on-device model; treat PCC and 27-only APIs as opt-in upgrades, not the baseline.

**Related skills:**
- **`apple-foundation-models`** (this skill) — decision points, hard-won rules, shipping checklist
- **`native-swiftui`** — availability/quota/error UI, `ContentUnavailableView`, native system presentation
- **`swiftui-project-structure`** — where feature code, prompt assets, and supporting packages should live
- **`swiftui-expert-skill`** — Observation, concurrency, performance, Instruments

## Agent workflow

1. **Gate by SDK first** — Foundation Models is **iOS 26+**; PCC, `ContextOptions`, and `DynamicProfile` are **iOS 27+ Beta**.
2. **Choose the smallest capable model** — start with `SystemLanguageModel`; only justify PCC when 4K context / no reasoning is the real blocker.
3. **Gate product UI on availability and locale** — use `model.availability`, `supportsLocale()`, and a non-AI fallback path.
4. **Choose the interaction shape** — one-shot session, reused multi-turn session, guided generation, or tool calling.
5. **Prefer typed output** — `@Generable` / `respond(to:generating:)` before raw-text parsing.
6. **Keep prompts/program logic separate** — compute branches in Swift, then inject only the relevant branch into the prompt.
7. **Budget tokens explicitly** — prompts, instructions, schemas, tools, tool output, transcript, and reasoning all count.
8. **Version prompts by OS/model generation** when output quality matters.

## Hard-won rules

### Model choice

- Default to **`SystemLanguageModel`** for summarization, extraction, rewrite/refinement, classification, and short creative generation.
- Do **not** rely on the on-device model for exact math, code generation, or heavy logical reasoning.
- For tagging/categorization, prefer **`SystemLanguageModel(useCase: .contentTagging, ...)`** over a generic free-form prompt.
- Move to **`PrivateCloudComputeLanguageModel`** only for a concrete need: larger context, stronger reasoning, or long/complex multi-turn flows.

### Session shape

- Fresh `LanguageModelSession` for **single-turn** tasks.
- Reuse a session only when the transcript is intentionally part of the feature.
- A session handles **one request at a time**; serialize requests or check `isResponding`.
- `prewarm(promptPrefix:)` is optional latency polish, never a correctness requirement.

### Prompting

- Give the on-device model **one concrete task per prompt**.
- Use **short imperative phrasing**: “Summarize…”, “Extract…”, “Classify…”.
- Ask for shorter output in the prompt before using `maximumResponseTokens`.
- Instructions outrank prompts; only place **trusted** content in instructions.
- If a prompt has several conditional branches, compute the branch in app code and inject only that case.

### Structured output

- Use `@Generable` instead of asking for JSON and parsing text yourself.
- Keep guides short; clear property names are often enough.
- Property declaration order matters.
- If the model needs to “show its work”, give it a **dedicated first reasoning field** so reasoning text doesn’t leak into the answer fields.

### Tool calling

- Use tools for grounding, current/app-local data, privileged framework access, or side effects.
- Don’t use tools when your app already knows the data and can put it directly in the prompt.
- Keep tool descriptions and argument guides short.
- Treat `.required` tool-calling mode as dangerous unless you define an exit condition.

### PCC

- PCC requires the **managed entitlement**, **network access**, and **quota-aware UI**.
- The app must handle usage limits and degraded fallback behavior; do not present PCC as always available.
- If PCC is unavailable or a network-dependent request fails, fall back to on-device when the feature can degrade gracefully.

### Product states, not just errors

Design explicit UX for:

- model unavailable / not ready
- unsupported locale
- context exceeded
- tool failure
- PCC quota reached / approaching limit
- PCC service/network failure

## Shipping checklist

- [ ] Deployment target is **iOS 26+** (and **27+** only for PCC/reasoning APIs)
- [ ] Availability UI covers available, not-ready, and ineligible cases
- [ ] Unsupported locale path is handled
- [ ] Session usage is serialized; no concurrent calls to one session
- [ ] Structured outputs use `@Generable` instead of raw JSON parsing
- [ ] Tool calling is only used where grounding/actions are needed
- [ ] `.required` tool-calling has an exit condition
- [ ] Prompt/schema/tool budget was checked against context size
- [ ] Prompt variants are gated for model/OS differences when behavior matters
- [ ] PCC path includes entitlement, quota UX, and on-device fallback

## Additional resources

- API availability, model/version matrix, locale handling, PCC notes: [references/api-and-availability.md](references/api-and-availability.md)
- Prompting, context budgeting, tool-calling traps, prompt versioning: [references/prompting-and-operations.md](references/prompting-and-operations.md)
- Foundation Models overview: <https://developer.apple.com/documentation/foundationmodels>
- Foundation Models updates: <https://developer.apple.com/documentation/updates/foundationmodels>