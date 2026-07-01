# agent-skills

Personal [Agent Skills](https://agentskills.io/specification) for AI coding agents — published for install via [`gh skill`](https://cli.github.com/manual/gh_skill).

## Skills

| Skill | Description |
|-------|-------------|
| **ralph-loop** | Run and orchestrate Ralph loops — fresh-context agent runs against a Markdown checklist, with guardrails, prompts, and loop scripts. |
| **ralph-loop-plan** | Write implementation plans and checklists sized for Ralph loops — one checkbox per agent run, integration tasks, human gates at the end. |

## Install

Requires [GitHub CLI](https://cli.github.com/) with `gh skill` support.

```bash
# Install both skills for Cursor (user scope — available on all projects)
gh skill install dbmrq/agent-skills --all --agent cursor --scope user

# Install for other agents
gh skill install dbmrq/agent-skills ralph-loop --agent claude-code --scope user
gh skill install dbmrq/agent-skills ralph-loop-plan --agent github-copilot --scope user

# Pin to a release
gh skill install dbmrq/agent-skills --all --pin v1.0.0 --agent cursor --scope user
```

Preview before installing:

```bash
gh skill preview dbmrq/agent-skills ralph-loop
```

Update after a new release:

```bash
gh skill update --all
```

## Publish (maintainer)

From a clone of this repo:

```bash
gh skill publish --dry-run    # validate only
gh skill publish --tag v1.0.0 # release
```

## Layout

```
skills/
  ralph-loop/
    SKILL.md
    prompt-template.md
    reference.md
    script-template.sh
  ralph-loop-plan/
    SKILL.md
    plan-template.md
    examples.md
```
