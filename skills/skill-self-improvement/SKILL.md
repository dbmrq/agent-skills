---
name: skill-self-improvement
description: >-
  Update the skill that was just used with durable new information learned
  during that use (corrected commands/paths, gotchas, missing steps, wrong
  assumptions), while keeping the skill concise. Apply this after using ANY
  skill to complete a task, every time — not only when explicitly asked to
  edit or improve a skill.
---

# Skill Self-Improvement

Runs alongside every skill use. After finishing work that relied on a skill, check whether that use taught something worth keeping, then patch the skill — don't wait to be asked.

## Workflow

1. Reflect: did using the skill surface something its SKILL.md got wrong, omitted, or that took extra digging to figure out?
2. Nothing new? Stop. Don't edit just to edit.
3. Something durable? Patch the skill that was used:
   - Edit the relevant section in place; don't just append to the end.
   - Remove or rewrite the outdated guidance in the same edit.
   - Keep the skill as concise as before — every new sentence must earn its place.
4. Locate the edit target correctly before writing:
   - Skill lives in the `dbmrq/agent-skills` repo → edit `skills/<name>/SKILL.md` there and use the **manage-agent-skills** skill's release workflow to publish.
   - Skill is external/vendored (e.g. `external-skills.json`, Apple Xcode export) or only an installed mirror (`~/.agents/skills`, `~/.claude/skills`, etc.) → don't edit the local copy; it's overwritten on next sync. Note the fix for upstream instead, or skip.

## Counts as new information

- A command, path, flag, or API that differs from what the skill documented
- A gotcha, failure mode, or edge case hit during this use
- A missing step that had to be improvised
- An example or assumption that misled the agent

## Doesn't count

- Anything a capable agent already knows or can regenerate from a quick lookup
- One-off, task-specific details unlikely to recur
- Chat noise, exploratory dead ends, secrets, or personal data
- A rewording of guidance already present in the skill

## Additional resources

- Edit mechanics, templates, and the commit/tag/sync release steps: see the **manage-agent-skills** skill — don't duplicate that process here.
