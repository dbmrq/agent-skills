# Skill authoring (agent-skills)

Default assumption: the model is already capable. Skills earn tokens by encoding what is hard to rediscover.

## Include

- Repo-specific paths, commands, release/install steps, and invariants
- Non-obvious APIs, merge semantics, failure modes, ordering constraints
- Concrete examples of good vs bad outputs when quality hinges on them
- Pointers to canonical upstream docs instead of pasting large specs

## Exclude

- Generic programming advice the model already knows
- Long tutorials, changelogs, or README-style human setup inside the skill package
- Secrets, tokens, personal data, or one-off incident notes
- Content that belongs in an **external** or Xcode skill — install it; don’t fork it here
- Chat transcripts pasted wholesale — distill to durable rules

## Description

- Third person; include trigger terms the user will say (“create a skill”, product names, file types).
- State **what** and **when** in frontmatter. A body “When to use” section is optional if the description already covers triggers.

## Freedom of instruction

| Fragility | Style |
|-----------|--------|
| High (release, publish, install) | Exact commands and order |
| Medium (structure, naming) | Templates + rules |
| Low (how to phrase domain help) | Short principles |

## Update heuristics

When folding a conversation or another repo into an existing skill:

1. **Durable only** — Keep procedures, gotchas, and invariants that will still be true next month. Drop exploratory wrong turns and environment-specific noise unless they are a documented trap.
2. **Patch, don’t append endlessly** — Merge into the relevant section; delete obsolete guidance in the same edit.
3. **Progressive disclosure** — If `SKILL.md` would exceed ~500 lines or bury the workflow, move detail to `references/<topic>.md` and link it from SKILL.md (one level deep). Put output skeletons in `assets/` when agents should copy them.
4. **Split or rename** when one skill serves two unrelated trigger sets — don’t keep growing a grab-bag. Prefer updating a close existing skill over a near-duplicate create.
5. **Conflicts with externals** — If Apple or upstream skills own the topic, link/install those; only keep local deltas that this repo uniquely needs.

## New-skill bar

Create a new skill only when there is a recurring workflow or non-obvious domain packet that agents will miss without it — and overlap checks found no existing owner.
