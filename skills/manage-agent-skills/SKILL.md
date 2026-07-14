---
name: manage-agent-skills
description: >-
  Create, update, release, and sync skills in the dbmrq/agent-skills repository
  (source of truth for personal Agent Skills). Use when the user asks to create
  a new skill, update an existing skill from a conversation or another repo,
  improve skill authoring practices, publish/release skills, or run install-all /
  gh skill sync — not when merely using a skill for its domain task.
---

# Manage agent-skills

Source of truth: **[dbmrq/agent-skills](https://github.com/dbmrq/agent-skills)** (`skills/<name>/`).

Installed copies under agent home dirs are **read-only mirrors**. Never invent or edit skills there.

## Hard rules

1. **Edit only in this repo** — `skills/<skill-name>/SKILL.md` (and siblings). Prefer a local clone of `dbmrq/agent-skills`; if absent, clone it and work there (do not patch install paths).
2. **Never write skills into** `~/.agents/skills`, `~/.cursor/skills`, `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, or any other agent skills directory. Those are overwritten by sync.
3. **Never vendor upstream skills** listed in `external-skills.json` (e.g. `swiftui-expert-skill`) or Apple Xcode exports. Update manifests/install only.
4. **Ship the change** — validate, commit, push, publish a tag, then sync installs (see [Release workflow](#release-workflow)). Do not leave skill edits only on the working tree unless the user asks to hold the release.

## Layout

```
skills/<skill-name>/
  SKILL.md          # required — frontmatter name MUST equal directory name
  references/       # optional — progressive disclosure
  scripts/          # optional
  assets/           # optional
```

Frontmatter (required): `name`, `description`. Follow [Agent Skills spec](https://agentskills.io/specification). Keep `SKILL.md` under ~500 lines; link one level deep to references.

After adding a skill: add a row to the catalog table in the repo `README.md`.

## Create or update

### Create

1. Confirm the skill does not already exist (`skills/`, README catalog, `gh skill preview dbmrq/agent-skills <name>`).
2. Choose a kebab-case `name` (max 64 chars, no consecutive hyphens).
3. Write `skills/<name>/SKILL.md` with a third-person `description` that states **what** and **when** (trigger phrases).
4. Add only non-obvious procedures, gotchas, commands, and domain facts (see [Authoring](#authoring)).
5. Update README catalog.
6. Run [Release workflow](#release-workflow).

### Update from a conversation or another repo

1. Locate the skill under `skills/<name>/` in the **agent-skills** clone (not the install dir, not the other project’s `.cursor/skills`).
2. Distill durable, reusable knowledge from the thread or foreign repo — omit one-off debugging noise and secrets.
3. Patch `SKILL.md` / references; avoid duplicating content that already lives in another local skill or an external skill.
4. Run [Release workflow](#release-workflow).

### If currently working in a different repository

Clone or open `dbmrq/agent-skills` as the edit target. Do not create a project-local skill in the other repo unless the user explicitly wants a **project-scoped** skill (rare; default is this personal collection).

## Release workflow

From the `agent-skills` repo root:

```bash
gh skill publish --dry-run
git status   # include skills/** and README.md as needed
# commit with a clear why-focused message, then:
git push -u origin HEAD
# bump from latest tag (e.g. v1.3.0 → v1.4.0):
gh skill publish --tag vX.Y.Z
./scripts/install-all.sh
```

- Prefer `./scripts/install-all.sh` over per-agent `gh skill install` so shared dirs and externals stay in sync.
- `gh skill publish --tag` creates the GitHub release consumers resolve as “latest.”
- Confirm with `gh skill list` / that the new or updated skill appears under the sync targets.

Commit/push/publish for skill changes is expected for this repo even when other projects’ defaults are “ask before commit.” Still do **not** force-push, amend others’ commits, or skip hooks.

## Authoring

Default assumption: the model is already capable. Skills earn their tokens by encoding what is hard to rediscover.

**Include**

- Repo-specific paths, commands, release/install steps, and invariants
- Non-obvious APIs, merge semantics, failure modes, ordering constraints
- Concrete examples of good vs bad outputs when quality hinges on them
- Pointers to canonical upstream docs instead of pasting large specs

**Exclude**

- Generic programming advice the model already knows
- Long tutorials, changelogs, or README-style setup for humans inside the skill package
- Secrets, tokens, personal data, or one-off incident notes
- Content that belongs in an **external** skill — install it; don’t fork it here

**Description**

- Third person; include trigger terms the user will say (“create a skill”, “update skill X”, product names).
- No “When to use” section needed in the body if the description already covers triggers.

**Freedom of instruction**

| Fragility | Style |
|-----------|--------|
| High (release, publish, install) | Exact commands and order |
| Medium (structure, naming) | Templates + rules |
| Low (how to phrase domain help) | Short principles |

## Related files in this repo

| Path | Role |
|------|------|
| `README.md` | Catalog + install docs — keep catalog rows current |
| `scripts/install-all.sh` | Sync this repo + externals + Xcode skills |
| `external-skills.json` | Upstream deps — do not vendor |

## Done checklist

- [ ] Changes live under `skills/<name>/` in **dbmrq/agent-skills**
- [ ] `name` matches directory; description has what + when
- [ ] No edits under agent install directories
- [ ] README catalog updated if new skill
- [ ] `gh skill publish --dry-run` passes
- [ ] Committed, pushed, tagged release, `./scripts/install-all.sh` run
