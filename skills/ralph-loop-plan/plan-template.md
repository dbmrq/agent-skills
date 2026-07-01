# {{Feature Name}} Implementation Plan

**Architecture spec:** [{{feature}}-architecture.md](./{{feature}}-architecture.md) *(or inline Architecture section below)*

## Goal

{{One paragraph: what this delivers and why.}}

## How this plan is used (Ralph loop)

This file is the **source of truth** for an automated Ralph loop. Each run, a fresh agent:

1. Reads this plan and the linked architecture spec
2. Implements the **next unchecked** checklist item only
3. Runs that item's verification
4. Marks the item `[x]` when verified
5. Adds **Notes for later items** when it learns something future agents need

The loop script (`scripts/ralph-loop.sh`) invokes agents until all checklist items are done. **Do not add checkboxes outside the Implementation Checklist** — human-only work goes in Manual Validation at the end.

## Architecture

*(Optional if separate spec exists. Keep stable — agents read this every run.)*

- {{Key decision 1}}
- {{Key decision 2}}
- {{Authority / data flow summary}}

## Contracts / invariants

- {{Rule agents must not violate}}
- {{Identity, format, or API contract}}

## Implementation Checklist

- [ ] **1. {{Foundation item — schema, scaffold, or core types}}.**  
  {{Scope: files, behavior, boundaries.}}  
  Verification: `{{exact test command or pass/fail criteria}}`

- [ ] **2. {{Vertical slice or second foundation piece}}.**  
  {{Scope.}}  
  Verification: `{{command}}`

- [ ] **3. {{Core feature A}}.**  
  {{Scope.}}  
  Verification: `{{command}}`

- [ ] **4. {{Core feature B}}.**  
  {{Scope.}}  
  Verification: `{{command}}`

- [ ] **5. {{Integration — wire layers together}}.**  
  {{Explicitly connect components; entry points, dependency injection, calls.}}  
  Verification: `{{integration test or build + test}}`

- [ ] **6. {{End-to-end scenario test}}.**  
  One test or serialized suite covering {{user story}} across components.  
  Verification: `{{scenario test command}}`

- [ ] **7. {{Cleanup / consolidation / optimization}}.**  
  Remove temp artifacts; consolidate duplicate logic; address known debt from earlier items.  
  Verification: `{{full test or lint command for affected area}}`

- [ ] **8. {{Documentation}}.**  
  User-facing docs, README, or API reference updates.  
  Verification: {{review criteria or doc tests if any}}

## Manual Validation After The Checklist

*(No checkboxes — requires human judgment, staging environments, or external systems.)*

- {{Staging or environment-specific manual test}}
- {{Design / product / accessibility review}}
- {{Production release or approval step}}
