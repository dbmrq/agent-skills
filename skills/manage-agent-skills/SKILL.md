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

Installed copies under agent home dirs are **read-only mirrors**. Never invent or edit skills there. Never commit install trees (e.g. repo-local `.agents/`) into git.

Authoring detail (what to include/exclude, update heuristics, templates): [references/authoring.md](references/authoring.md) · skeleton: [assets/SKILL.template.md](assets/SKILL.template.md)

## Hard rules

1. **Edit only in this repo** — `skills/<skill-name>/SKILL.md` (and siblings). Locate or clone `dbmrq/agent-skills`; do not patch install paths.
2. **Never write skills into** `~/.agents/skills`, `~/.cursor/skills`, `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, or any other agent skills directory (including symlinked hubs under dotfiles). Sync overwrites those.
3. **Never vendor upstream skills** listed in `external-skills.json` or Apple Xcode exports. Update manifests/install only.
4. **Default: ship** — validate, commit on `main`, push `main`, publish a tag, sync installs. If the user says draft / don’t release / hold, stop after the edit (optional local commit only — no push/tag/sync).
5. **No PRs** — push commits directly to `main`. Do not open pull requests for skill changes unless the user explicitly asks.

## Find the edit target

Resolve in order; stop at the first that is a git checkout of `dbmrq/agent-skills` with a `skills/` directory:

1. Current workspace (cwd / git root is this repo)
2. An already-open clone elsewhere on the machine
3. `gh repo clone dbmrq/agent-skills` (or `git clone https://github.com/dbmrq/agent-skills.git`) into a sensible working location, then edit there

**Not** valid edit targets (even if they contain `SKILL.md` files): anything under `~/.agents`, `~/.cursor/skills`, `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, or a dotfiles skills hub that is only an install mirror.

Project-local skills in *other* repos (e.g. `.cursor/skills/` inside an app) only when the user explicitly wants a **project-scoped** skill — default remains this personal collection.

## When not to create a skill

Prefer **no new skill** when:

- The request is a one-off task or machine-specific note
- An existing skill in `skills/`, `external-skills.json`, or the Xcode set already covers it — **update or point users at that** instead
- Content would only restate what a capable model already knows (see [authoring](references/authoring.md))

## Overlap check (before create)

1. `skills/` and the README catalog
2. `external-skills.json` (must not vendor; may document install-only)
3. Apple Xcode skills (see README / `external-skills.json` `xcode_skills`) — do not fork into this repo
4. Optional: `gh skill preview dbmrq/agent-skills <name>` and `gh skill list`

Near-duplicate of a local skill → **update** that skill (or split/rename deliberately), don’t add a twin.

## Create or update

### Create

1. Pass [overlap check](#overlap-check-before-create) and [when not to create](#when-not-to-create-a-skill).
2. Choose kebab-case `name` (max 64 chars, no consecutive hyphens; must match directory).
3. Copy [assets/SKILL.template.md](assets/SKILL.template.md) → `skills/<name>/SKILL.md` and fill it in. Authoring rules: [references/authoring.md](references/authoring.md).
4. Add a README catalog row.
5. Run [Release workflow](#release-workflow) (or draft stop if requested).

### Update from a conversation or another repo

1. Open the skill under `skills/<name>/` in the **agent-skills** clone.
2. Distill durable rules — see [Update heuristics](references/authoring.md#update-heuristics). Omit secrets, one-off debugging, and chat noise.
3. Prefer patching existing sections; add `references/` when SKILL.md would bloat. Avoid duplicating another local or external skill.
4. Run [Release workflow](#release-workflow) (or draft stop if requested).

## Release workflow

From the **agent-skills** repo root, on **`main`** (no feature branch / no PR):

```bash
gh skill publish --dry-run

git status   # skills/** and README.md; never stage .agents/ or other install trees
# commit with a why-focused message, then:
git push -u origin main

# Next tag from REMOTE (local tags are often stale):
latest="$(gh release list --limit 1 --json tagName -q '.[0].tagName')"
# bump per Semver below → e.g. v1.5.0 → v1.6.0
gh skill publish --tag vX.Y.Z

./scripts/install-all.sh
```

**Semver (this repo):**

| Bump | When |
|------|------|
| **patch** (`v1.5.0` → `v1.5.1`) | Copy tweaks, small fixes, no new skill |
| **minor** (`v1.5.0` → `v1.6.0`) | New skill, material behavior/content change, new workflow |
| **major** | Only if intentionally breaking how consumers should use the collection (rare) |

Resolve `latest` with `gh release list` or `git ls-remote --tags origin` — **not** `git tag` alone.

- Prefer `./scripts/install-all.sh` over per-agent `gh skill install`.
- Skill commits may ship without re-asking even when other projects say “ask before commit.” Still: no force-push, no amending others’ commits, no skipping hooks.

### Post-sync verification

After `./scripts/install-all.sh`:

```bash
# Canonical shared hub (often ~/.agents/skills; may be a symlink into dotfiles)
hub="${HOME}/.agents/skills"
test -f "${hub}/<name>/SKILL.md"
# Description / title matches what you just published (not a stale copy)
grep -q '<distinctive-phrase-from-new-description>' "${hub}/<name>/SKILL.md"
```

If the hub path differs on this machine, use the path `install-all.sh` printed under `targets:`. Also fine: `gh skill list` showing the skill for expected agents.

## Layout

```
skills/<skill-name>/
  SKILL.md          # required — name MUST equal directory name
  references/       # optional
  scripts/          # optional
  assets/           # optional
```

Frontmatter: `name`, `description` ([spec](https://agentskills.io/specification)). Keep `SKILL.md` under ~500 lines; references one level deep.

## Related files in this repo

| Path | Role |
|------|------|
| `README.md` | Catalog + install docs — keep catalog rows current |
| `scripts/install-all.sh` | Sync this repo + externals + Xcode skills |
| `external-skills.json` | Upstream deps — do not vendor |
| `.gitignore` | Must ignore `.agents/` (install trees must not be committed) |

## Done checklist

- [ ] Changes under `skills/<name>/` in **dbmrq/agent-skills** (not an install dir)
- [ ] Overlap check done; no accidental upstream fork
- [ ] `name` matches directory; description has what + when
- [ ] README catalog updated if new skill
- [ ] `gh skill publish --dry-run` passes; no `.agents/` staged
- [ ] Committed and pushed to **`main`** (no PR)
- [ ] Tag chosen from **remote** latest + Semver; `gh skill publish --tag` succeeded
- [ ] `./scripts/install-all.sh` run; [post-sync verification](#post-sync-verification) passed  
  — or stopped at draft per user request
