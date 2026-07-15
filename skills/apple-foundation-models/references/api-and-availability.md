# API and availability notes

Use this file when the implementation depends on **exact API availability**, **which model to choose**, or **what fallback/UI states must exist**.

## Availability matrix

| Concern | API | Availability | Notes |
|--------|-----|--------------|-------|
| Base framework | `FoundationModels` | iOS 26.0+ | Don’t propose this for older deployment targets. |
| On-device model | `SystemLanguageModel` | iOS 26.0+ | Availability still depends on Apple Intelligence device + region support. |
| General session | `LanguageModelSession()` | iOS 26.0+ | Default session uses the system model. |
| Guided generation | `@Generable`, `@Guide` | iOS 26.0+ | Prefer over raw JSON text parsing. |
| Tool calling | `Tool`, `GenerationOptions.ToolCallingMode` | iOS 26.0+ | Use for grounding/actions, not by default. |
| Specialized tagging model | `SystemLanguageModel(useCase: .contentTagging, ...)` | iOS 26.0+ | Better fit for tagging/classification flows. |
| Prompt token counting | `SystemLanguageModel.default.tokenCount(for:)` | iOS 26.4+ | High-value for budgeting prompts/schemas/tools. |
| Context size query | `SystemLanguageModel.default.contextSize` | iOS 26.4+ | On-device context is **4,096 tokens**. |
| PCC model | `PrivateCloudComputeLanguageModel` | iOS 27.0+ Beta | Requires managed entitlement + network + quota-aware UX. |
| Reasoning/context options | `ContextOptions` | iOS 27.0+ Beta | Reasoning levels are 27+ only. |
| Dynamic profiles | `LanguageModelSession.DynamicProfile` | iOS 27.0+ Beta | Powerful, but new/beta — use only when dynamic behavior is truly needed. |

## Model-selection rules

### Start with `SystemLanguageModel`

Good default fit:

- summarization
- extraction
- classification / judgment
- rewrite / refinement
- short creative generation
- short multi-turn assistance with app-local context

Bad fit unless carefully constrained or augmented:

- exact math
- code generation
- heavy logical reasoning / puzzle solving
- long documents / long transcripts
- workflows that need current external knowledge without tools

If the feature is specifically **content tagging**, prefer `SystemLanguageModel(useCase: .contentTagging, ...)` instead of a generic prompt.

### Move to PCC only for a clear reason

Use `PrivateCloudComputeLanguageModel` when evaluation shows you need:

- **32K** context instead of 4K
- **reasoning levels** (`.light`, `.moderate`, `.deep`)
- better handling of long or complex multi-step tasks

PCC tradeoffs that must be visible in the design:

- managed entitlement: `com.apple.developer.private-cloud-compute`
- network dependency
- daily quota / upgrade path UX
- iOS 27+ / matching newer Apple OS only
- still requires Apple Intelligence eligible device + region

## Availability-driven UI states

### On-device model

Handle at least these states:

- `.available`
- `.unavailable(.deviceNotEligible)`
- `.unavailable(.modelNotReady)`
- generic unavailable fallback

`modelNotReady` commonly means the model is still downloading or otherwise not ready after Apple Intelligence was enabled.

### PCC model

Handle at least these states:

- `.available`
- `.unavailable(.deviceNotEligible)`
- `.unavailable(.systemNotReady)`
- generic unavailable fallback

Unlike the on-device model, PCC also requires network/service availability during the request itself.

## Locale handling

- Call `SystemLanguageModel.default.supportsLocale()` before enabling the feature when app language can vary per-app.
- If locale support is unclear, handle `LanguageModelError.unsupportedLanguageOrLocale(_)` as a user-facing fallback state.
- For non-U.S. English locales, Apple recommends the exact instruction phrase: **`The person's locale is xx_YY.`**
- If output must be in a specific language, say so explicitly in instructions: **`You MUST respond in Italian.`**

Non-obvious safety note: guardrails are only reliable for **supported languages/locales**. Mixed prompts with short unsupported-language fragments may bypass both unsupported-language detection and guardrail flagging.

## Model-version generations to care about

Prompt behavior should currently be thought of in these buckets:

- **26.0–26.3**
- **26.4**
- **27.x**

Important changes Apple has called out:

- **26.4**: better instruction following/tool calling; `tokenCount(for:)`; `contextSize`
- **27.x**: newer on-device model; PCC; `ContextOptions`; `DynamicProfile`; expanded model/error surface

Do not assume prompt behavior is stable across those generations.

## PCC-specific UX and failure handling

If the app uses PCC, inspect `model.quotaUsage` and design for:

- approaching limit
- limit reached
- optional upgrade UI via `limitIncreaseSuggestion.show()`
- `quotaLimitReached`
- `networkFailure`
- `serviceUnavailable`

Fallback rule: if PCC fails for network/service reasons and the feature can degrade, retry with the on-device model.

## Canonical docs

- Foundation Models overview: <https://developer.apple.com/documentation/foundationmodels>
- Foundation Models updates: <https://developer.apple.com/documentation/updates/foundationmodels>
- SystemLanguageModel: <https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel>
- Private Cloud Compute: <https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute>
- Supporting languages/locales: <https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models>