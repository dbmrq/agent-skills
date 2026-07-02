# agent-skills

Personal collection of [Agent Skills](https://agentskills.io/specification) for AI coding agents. Install with [`gh skill`](https://cli.github.com/manual/gh_skill) or the bundled script (see below).

This repository is the **source of truth for skills maintained here**. One upstream SwiftUI skill is documented as an external dependency and installed alongside — not vendored (see [SwiftUI stack](#swiftui-stack)).

## Skills catalog

| Skill | When to use |
|-------|-------------|
| [ralph-loop](skills/ralph-loop/) | Run and orchestrate Ralph loops — fresh-context agent runs against a Markdown checklist, with guardrails, prompts, and loop scripts. |
| [ralph-loop-plan](skills/ralph-loop-plan/) | Write implementation plans and checklists sized for Ralph loops — one checkbox per agent run, integration tasks, human gates at the end. |
| [xcodegen](skills/xcodegen/) | Author and debug XcodeGen `project.yml` specs — merge semantics, settings traps, dependencies, multiplatform targets, schemes, and cache behavior. |
| [native-swiftui](skills/native-swiftui/) | Build native-looking iOS UIs with highest-level SwiftUI components, system styles, semantic colors, and standard navigation (`NavigationStack`, `GroupBox`, built-in button styles). |
| [swiftui-view-composition](skills/swiftui-view-composition/) | Structure and refactor SwiftUI views — extract dedicated `View` structs, `ViewModifier`s, and layout helpers for readable, reusable screens instead of bloated `body` properties. |
| [swiftui-project-structure](skills/swiftui-project-structure/) | Organize SwiftUI repos like Apple samples — feature folders, Swift packages, multiplatform targets, App/Scene wiring, and MV vs Store/ViewModel layer decisions. |

Browse skills in this repo:

```bash
gh skill install dbmrq/agent-skills          # lists available skills
gh skill preview dbmrq/agent-skills <skill>    # read before installing
```

## SwiftUI stack

Four skills work together for SwiftUI work. **Three live in this repo**; the fourth is upstream:

| Skill | Source | Role |
|-------|--------|------|
| [swiftui-project-structure](skills/swiftui-project-structure/) | **this repo** | Repo layout, packages, App/Scene wiring, architecture layers |
| [swiftui-view-composition](skills/swiftui-view-composition/) | **this repo** | Extract views, modifiers, refactor bloated `body` |
| [native-swiftui](skills/native-swiftui/) | **this repo** | System components, HIG-aligned styling, navigation shells |
| [swiftui-expert-skill](https://github.com/avdlee/swiftui-agent-skill) | **[avdlee/swiftui-agent-skill](https://github.com/avdlee/swiftui-agent-skill)** | State management, performance, lists, animations, Instruments traces, Liquid Glass |

The expert skill is maintained by [Antoine van der Lee](https://github.com/avdlee) — do not copy it into this repo. Install it from upstream via `./scripts/install-all.sh`.

External dependency manifest: [`external-skills.json`](external-skills.json).

## Install and update

Requires [GitHub CLI](https://cli.github.com/) with `gh skill` support.

### Everything (recommended)

Install fresh or pull the latest versions — same command either way:

```bash
./scripts/install-all.sh cursor user
```

Defaults: `cursor` + `user` scope if you omit arguments:

```bash
./scripts/install-all.sh
```

This syncs all skills from **this repo** plus **swiftui-expert-skill** from `avdlee/swiftui-agent-skill`, resolving each to the **latest git tag** (or default-branch HEAD when untagged).

Re-run after any release — yours or upstream — to refresh.

### This repo only

```bash
# One skill
gh skill install dbmrq/agent-skills <skill-name> --agent cursor --scope user

# Every skill in this repo (latest)
gh skill install dbmrq/agent-skills --all --agent cursor --scope user
```

### Upstream expert skill only

```bash
gh skill install avdlee/swiftui-agent-skill swiftui-expert-skill --agent cursor --scope user
```

### Pinning (optional)

For reproducible CI or debugging, pass pins via environment variables:

```bash
AGENT_SKILLS_PIN=v1.0.0 SWIFTUI_EXPERT_PIN=4.0.0 ./scripts/install-all.sh
```

Common `--agent` values: `cursor`, `claude-code`, `github-copilot`, `codex`, `augment`, `cline`, `warp`. Use `--scope user` for skills available in all projects, or `--scope project` for repo-local installs.

## Repository layout

Each skill is a directory under `skills/` with a `SKILL.md` entry point (per the Agent Skills spec). Supporting files (templates, scripts, references) live alongside it.

```
skills/
  <skill-name>/
    SKILL.md          # required — name must match directory
    ...               # optional reference files, scripts, examples
```

## Maintainer workflow

**Clone and edit** (do not edit files under `~/.cursor/skills/` directly — installs are copies that `gh skill update` overwrites):

```bash
git clone https://github.com/dbmrq/agent-skills.git
cd agent-skills
# add or edit skills/<name>/SKILL.md
```

**Validate and release:**

```bash
gh skill publish --dry-run       # validate all skills
gh skill publish --tag v1.1.0    # create GitHub release
./scripts/install-all.sh         # refresh local installs to latest
```

**Adding a new skill:**

1. Create `skills/<skill-name>/SKILL.md` with valid frontmatter (`name`, `description`).
2. Ensure `name` in frontmatter matches the directory name.
3. Add a row to the catalog table in this README.
4. Run `gh skill publish --dry-run`, commit, push, and publish a new tag.

## License

Skills in this repository are provided as-is for personal use. Individual skills may specify their own license in frontmatter as the collection grows.
