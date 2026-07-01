---
name: ralph-loop-plan
description: >-
  Write Markdown implementation plans and checklists optimized for Ralph loops
  — one checkbox per agent run, autonomous ordering, integration tasks,
  verification criteria, and human-only gates at the end. Use when the user
  wants a Ralph loop plan, autonomous agent todo list, or says "use a ralph
  loop to build/create X" and needs the plan before running the loop.
---

# Ralph Loop Plan

## When to use

- User wants to **build something with a Ralph loop** but has no plan yet
- User asks for an **agent-suitable todo list** or **implementation checklist**
- User wants to **review or improve** an existing Ralph loop plan

After creating the plan, use the **ralph-loop** skill to generate `scripts/ralph-loop.sh` and run the loop.

## What makes a Ralph-ready plan

A Ralph loop plan is not a generic todo list. It is a **state file on disk** that fresh agents read each run to decide what to do next.

Each `- [ ]` checkbox = **exactly one agent invocation**. The loop script counts unchecked boxes and stops when they are all `[x]`.

Human work belongs in a **separate section without checkboxes** at the end so the script does not spawn agents for it.

## Quick workflow

When the user says *"use a Ralph loop to build/create X"*:

1. **Clarify** goal, stack, constraints (only if missing — do not block on perfection).
2. **Write architecture/spec** section or link to a separate spec file for stable design reference.
3. **Break work into numbered checklist items** sized for one agent run each.
4. **Order for autonomy** — everything agents can do without humans first; manual validation last.
5. **Add integration, scenario, and cleanup items** — not only isolated features.
6. **Save** as `docs/<feature>-plan.md` (or user-chosen path).
7. **Offer** to generate the loop script via **ralph-loop** skill.

## Plan document structure

Use [plan-template.md](plan-template.md). Required sections:

| Section | Purpose |
|---------|---------|
| Title + goal | One paragraph: what and why |
| How Ralph loops work here | 3–5 lines so each agent understands its role |
| Architecture/spec link | Stable design; agents read before coding |
| Contracts / invariants | Rules that must not be violated across items |
| Implementation Checklist | Numbered `- [ ]` items — **only section with checkboxes** |
| Manual validation | Human-only; **no checkboxes** |

Optional: file format contract, migration rules, glossary — keep long specs out of checklist items; link instead.

## Task sizing (one checkbox = one agent run)

### Right size

One item should be completable in a single fresh-context run (~15–45 min of agent work):

- Add one module or cohesive layer with tests
- Wire one integration point (e.g. service → API, library → CLI, module → UI)
- One scenario test covering a user flow slice
- One refactor/cleanup pass with verification

Each item includes:

1. **Bold numbered title** — `- [ ] **N. Short title.**`
2. **Implementation scope** — what to build/change (2–6 sentences)
3. **Verification** — exact command, test target, or pass/fail criteria (use the repo's existing test/lint/build tooling — do not assume a specific stack)

### Too large (split)

- "Build the entire backend"
- "Add full UI" (split per screen or flow)
- "Implement entire data pipeline" (split: schema → ingest → transform → API → UI → scenarios)

Split along **natural seams** where each piece still **builds and verifies** independently.

### Too small (merge)

- "Add import statement"
- "Rename one variable"
- "Fix typo in comment"

Merging reduces loop overhead and leaves room for meaningful verification.

### Sizing heuristic

Ask: *Can an agent read the spec, implement this, run verification, update the plan with notes, and exit — without needing another item immediately?*

If yes → one item. If it needs a follow-up in the same breath → merge or split differently.

## Ordering for autonomous runs

```
Foundation → Core features → Integration wiring → Scenario tests → Hardening/cleanup → Docs
                                                                    ↓
                                                          Manual validation (human)
```

Rules:

1. **Dependencies first** — data/types before logic before interface before e2e.
2. **Vertical slices when possible** — a thin end-to-end path early proves architecture (often items 2–4).
3. **Integration explicit** — dedicated items to connect layers; never assume "it will wire itself."
4. **Scenario tests** — at least one item near the end exercises real user flows across components.
5. **Cleanup pass** — dedupe, remove temp artifacts, consolidate orchestration, optimize hot paths.
6. **Human gates last** — staging deploys, hardware-specific testing, design sign-off, production release.

## Checkbox format

Use numbered bold titles so scripts can parse reliably:

```markdown
- [ ] **7. Add settings page for notification preferences.**  
  Wire form state to existing user settings API. Handle save errors and loading states.  
  Verification: `npm test -- SettingsPage.test.tsx` — pass.
```

Completed:

```markdown
- [x] **6. Add input parser for config files.**  
  ...  
  Verification: `cargo test parser::` — pass.  
  **Notes for later items:** Call `parse_config()` from loader (item 8). Unknown keys must be preserved, not dropped.
```

See [examples.md](examples.md) for more patterns. Examples use varied stacks **only to show shape** — always match the target project's tools and conventions.

### Notes for later items (required habit)

When an agent completes an item, it should leave **Notes for later items** if it learned:

- Exact verification commands that work
- File paths and types to use
- Gotchas, flags, or ordering constraints
- Decisions that affect downstream items

Write notes **under the completed item** and/or on **specific future items**. This is how the plan improves without restructuring.

## Integration and "actually works"

Plans fail when items build isolated pieces that never connect. Prevent this:

| Phase | Example items |
|-------|----------------|
| Early slice | Minimal schema/model + one read path + one test |
| Wire-up | Connect service to existing HTTP handler, CLI, or UI shell |
| Cross-cutting | Error handling, logging, config |
| Scenario | One end-to-end test mirroring a user story |
| Hardening | Performance, edge cases, parallel test stability |

**Every feature plan should include** at least:

- One **integration** checkbox (layers connected)
- One **scenario / e2e** checkbox (proves cohesive behavior)
- One **cleanup/consolidation** checkbox if the feature touched 5+ areas

Verification must be **machine-runnable** where possible — not "manual test" inside checkbox items.

## Human-only section (no checkboxes)

```markdown
## Manual Validation After The Checklist

This section intentionally has no checkboxes — the Ralph loop script only drives checkbox items.

- Deploy to staging and smoke-test critical flows manually
- Design or product review (copy, layout, accessibility)
- Production release approval per team process
```

The Ralph loop script must not treat these as agent tasks.

## Cleanup and quality items

Include explicit late-plan items when the feature likely leaves debris:

- Consolidate duplicate orchestration into one coordinator
- Remove debug hooks, temp files, feature flags
- Optimize known hot paths discovered during implementation
- Fix flaky tests exposed by parallel runs
- Update user-facing docs and help copy

Label clearly: **"Perform final integration hardening"**, **"Consolidate X"**, **"Remove temporary Y"**.

## Architecture spec handling

- **Small features** — inline `## Architecture` section in the plan (≤80 lines).
- **Large features** — separate `docs/<feature>-architecture.md`; plan links to it.
- Checklist items say *what* to build; spec says *how* and *invariants*.
- Do not duplicate the whole spec in every item — reference sections.

## Anti-patterns

| Bad | Good |
|-----|------|
| Checkbox for "get user approval" | Note in Manual Validation |
| Item with no verification | Always state command or criteria |
| 50 tiny checkboxes | Merge related work |
| 3 mega checkboxes | Split by layer or flow |
| `[ ]` in code examples inside spec | Use fenced examples without task-list syntax |
| Reordering items during loop | Plan amendment note at bottom instead |

## Review checklist (before handing off)

- [ ] Every checkbox is one agent run, not zero and not three
- [ ] Items are ordered for autonomous execution
- [ ] Integration and scenario test items exist
- [ ] Cleanup/hardening item included when needed
- [ ] Human work is in Manual Validation without checkboxes
- [ ] Each item has Verification using this repo's tooling
- [ ] Ralph intro paragraph explains the loop to future agents
- [ ] Spec/architecture linked or embedded
- [ ] Plan path agreed (`docs/...-plan.md`)

## Related

- **Run the loop / write script** → **ralph-loop** skill
- **Copy-paste template** → [plan-template.md](plan-template.md)
- **Worked patterns (stack-neutral)** → [examples.md](examples.md)
