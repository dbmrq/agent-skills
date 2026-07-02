# agent-skills

Personal collection of [Agent Skills](https://agentskills.io/specification) for AI coding agents. Install any skill with [`gh skill`](https://cli.github.com/manual/gh_skill) on any machine.

This repository is the **single source of truth** for skills I maintain. New skills are added under `skills/` over time; each release is published as a tagged GitHub release.

## Skills catalog

| Skill | When to use |
|-------|-------------|
| [ralph-loop](skills/ralph-loop/) | Run and orchestrate Ralph loops — fresh-context agent runs against a Markdown checklist, with guardrails, prompts, and loop scripts. |
| [ralph-loop-plan](skills/ralph-loop-plan/) | Write implementation plans and checklists sized for Ralph loops — one checkbox per agent run, integration tasks, human gates at the end. |
| [xcodegen](skills/xcodegen/) | Author and debug XcodeGen `project.yml` specs — merge semantics, settings traps, dependencies, multiplatform targets, schemes, and cache behavior. |
| [native-swiftui](skills/native-swiftui/) | Build native-looking iOS UIs with highest-level SwiftUI components, system styles, semantic colors, and standard navigation (`NavigationStack`, `GroupBox`, built-in button styles). |
| [swiftui-view-composition](skills/swiftui-view-composition/) | Structure and refactor SwiftUI views — extract dedicated `View` structs, `ViewModifier`s, and layout helpers for readable, reusable screens instead of bloated `body` properties. |

Browse all skills:

```bash
gh skill install dbmrq/agent-skills          # lists available skills
gh skill preview dbmrq/agent-skills <skill>    # read before installing
```

## Install

Requires [GitHub CLI](https://cli.github.com/) with `gh skill` support.

```bash
# One skill
gh skill install dbmrq/agent-skills <skill-name> --agent cursor --scope user

# Every skill in this repo
gh skill install dbmrq/agent-skills --all --agent cursor --scope user

# Pin to a release (recommended on new machines)
gh skill install dbmrq/agent-skills --all --agent cursor --scope user --pin v1.0.0
```

Common `--agent` values: `cursor`, `claude-code`, `github-copilot`, `codex`, `augment`, `cline`, `warp`. Use `--scope user` for skills available in all projects, or `--scope project` for repo-local installs.

Update installed skills after a new release:

```bash
gh skill update --all
```

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
gh skill update --all            # refresh local installs
```

**Adding a new skill:**

1. Create `skills/<skill-name>/SKILL.md` with valid frontmatter (`name`, `description`).
2. Ensure `name` in frontmatter matches the directory name.
3. Add a row to the catalog table in this README.
4. Run `gh skill publish --dry-run`, commit, push, and publish a new tag.

## License

Skills in this repository are provided as-is for personal use. Individual skills may specify their own license in frontmatter as the collection grows.
