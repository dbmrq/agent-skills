---
name: ralph-loop
description: >-
  Run and orchestrate Ralph loops — repeated fresh-context agent runs against a
  Markdown checklist until work is verified and complete. Covers loop theory,
  guardrails, per-run prompts, plan enrichment, and writing ralph-loop shell
  scripts. Use when the user mentions Ralph loops, ralph-loop.sh, autonomous
  agent iteration, or wants to run agents repeatedly against a plan checklist.
---

# Ralph Loop

## When to use

- User wants to **run** a Ralph loop against an existing plan
- User wants to **write or improve** a `ralph-loop.sh` (or equivalent) script
- User is **inside** a loop run (prompt mentions automated Ralph loop)
- User asks how Ralph loops work

If there is **no plan yet**, create one first with the **ralph-loop-plan** skill, then return here for the script and orchestration.

## What a Ralph loop is

A Ralph loop runs a coding agent **repeatedly with a fresh context each time**, not one long chat.

| Layer | Role |
|-------|------|
| **Prompt** | Same instructions every run; tells each agent how to reorient |
| **State on disk** | Markdown checklist, specs, logs, git history — survives between runs |
| **Orchestrator** | Shell script (or stop-hook) that invokes the agent, detects progress, stops safely |
| **Verification** | Tests, linters, builds — gate whether an item may be marked done |

**Core insight:** the agent does not carry the whole project in memory. The filesystem and git do. Each run reads current state, does **one checklist item**, verifies, updates the plan, exits. The script starts the next run.

Named after Geoffrey Huntley's formulation: *"Ralph is a Bash loop"* — `while` + agent CLI + prompt file.

## End-to-end workflow

When the user says *"use a Ralph loop to build/create X"* (any stack — app, library, CLI, service):

1. **Plan** — Use **ralph-loop-plan** to write `docs/<feature>-plan.md` (or user-chosen path).
2. **Script** — Generate `scripts/ralph-loop.sh` from [script-template.sh](script-template.sh); point `--plan-file` at the plan.
3. **Dry run** — `./scripts/ralph-loop.sh --dry-run` to inspect the first prompt.
4. **Run** — `./scripts/ralph-loop.sh` (optionally tune `--max-runs`, `--max-no-progress-runs`).
5. **Human gate** — After all checkboxes are done, user runs the plan's non-checkbox manual validation section.

## Per-run agent prompt (canonical)

Use this shape. Adapt paths and repo name; keep the rules intact.

```markdown
You are running inside an automated Ralph loop.

Goal:
Work on the next unchecked item in `<PLAN_FILE>`, verify it, then mark it done only if verification actually passed.

Operating rules:
- Read `<PLAN_FILE>` first. It is the source of truth for scope and ordering.
- Work on **only** the next unchecked checklist item. Do not start later items.
- Keep changes scoped to that item; follow existing project patterns.
- Add or update focused tests when appropriate for this item.
- Run the fastest relevant verification (unit tests, lint, build) and record the exact command in your summary.
- When complete, change that item's checkbox from `[ ]` to `[x]`.
- If you discover constraints, commands, file paths, or dependencies that future agents would struggle to rediscover, add a **Notes for later items:** block under the completed item or on relevant future unchecked items. Do not rewrite unrelated plan sections.
- If blocked or unsafe to complete, document the blocker under that item, leave it unchecked, and stop.
- Do not create git commits unless the loop script explicitly tells you to; many loops commit after each run automatically.
- Do not expand scope, refactor unrelated code, or reorder checklist items.

Before finishing, report: what changed, what verification ran (with result), whether the item was marked complete, and any plan notes you added.
```

See [prompt-template.md](prompt-template.md) for a fill-in version with run metadata.

## Guardrails (always enforce)

These belong in **both** the script and the per-run prompt.

### Hard stops (script)

| Guardrail | Why |
|-----------|-----|
| `--max-runs` | Absolute ceiling on agent invocations |
| `--max-no-change-runs` | Stop when N consecutive runs change nothing (agent stuck or done but plan not updated) |
| `--max-no-progress-runs` | Stop when N consecutive runs change files but no checkbox gets checked (thrashing) |
| Clean git state at start | Avoid agents committing unrelated WIP (allow only plan + script + loop artifacts unless `--allow-dirty`) |
| No merge/rebase in progress | Prevent corrupted automation state |
| Agent failure = exit non-zero | Do not silently continue after a crashed run |
| Log every run to `.ralph-loop/logs/` | Debuggability without chat history |

### Soft rules (prompt)

| Rule | Why |
|------|-----|
| One item per run | Prevents context blow-up and scope creep |
| Verify before checking off | Stops false progress |
| Blocker docs, not silent skip | Next run can see why work stopped |
| Scoped plan edits only | Agents improve the plan without restructuring it |

### Optional extras

- **`--dry-run`** — Print first prompt; no agent call.
- **Completion promise** — Agent emits `<promise>COMPLETE</promise>` when plan is empty; script validates. Useful for hook-based loops; checklist counting is often enough for shell loops.
- **Baseline test run before loop** — Ensures agents don't inherit an already-red tree (document in plan item 1).

## Improving the plan during loops

Agents **should** enrich the plan; they **must not** destabilize it.

**Allowed (encourage):**

- `**Notes for later items:**` under a completed item — implementation discoveries, test commands, gotchas, file paths
- Short additions on **future unchecked items** — verification command, dependency ("requires item 7 first"), known pitfall
- Blocker subsection under a **stuck** item — what failed, what was tried, what human decision is needed

**Forbidden:**

- Renumbering or reordering items mid-loop
- Deleting unchecked items without user approval
- Marking items done without verification
- Moving human-only work into checkbox items

If an agent finds the plan structure itself is wrong (missing integration phase, item too large), add a **Plan amendment** note at the bottom and leave a checkbox unchecked with the blocker — do not silently reorganize.

## Writing a ralph-loop script

Use [script-template.sh](script-template.sh) as the starting point. Key non-obvious implementation details:

### 1. Fresh process each iteration

Each run is a **new agent process** with `-p "$prompt"`. Do not reuse one long session — that defeats the loop.

Detect CLI: `agent`, `cursor-agent`, or `cursor agent`. Honor `CURSOR_AGENT_BIN`.

### 2. Progress detection = checklist parsing

Count unchecked items with a stable pattern. Prefer numbered items:

```regex
^\s*-\s+\[\s\]\s+\*\*\d+\.
```

Generic fallback for unnumbered plans:

```regex
^\s*-\s+\[\s\]\s+
```

Expose `unchecked_count`, `next_unchecked_item`, and compare before/after each run.

### 3. Two different "stuck" signals

- **No file changes** — Agent may have exited without doing work, or work was already done.
- **File changes but same unchecked count** — Agent worked but did not finish or forgot to check off. Track separately from no-change.

### 4. Commit strategy

Common pattern: script commits after each run that changed files (`ralph-loop: run N`). Agent prompt says **do not commit** to avoid double commits. Pick one owner — script is usually safer.

### 5. Allowed dirty paths at start

When enforcing clean tree, always allow: the plan file, the loop script, `.ralph-loop/`, and `.gitignore`. Pass plan path dynamically — do not hardcode project-specific paths.

### 6. Pre-flight

```bash
git rev-parse --show-toplevel   # must be in repo
test -f "$PLAN_FILE"            # plan exists
test ! -f .git/MERGE_HEAD       # no merge
```

### 7. Exit codes

| Code | Meaning |
|------|---------|
| 0 | Plan complete or nothing left to do |
| 1 | Error, stuck guardrail, or max runs exceeded |

## Working inside a loop (agent checklist)

When the prompt says you are in a Ralph loop:

1. Read the full plan (at least through the next unchecked item and any linked spec).
2. Identify the **first** `- [ ]` checkbox item.
3. Implement only that item.
4. Run verification listed in the item (or the fastest relevant default for this repo).
5. Mark `[x]` only if verification passed.
6. Add **Notes for later items** if you learned something non-obvious.
7. Summarize for the log; exit cleanly.

If blocked: document under the item; leave unchecked; stop.

## Script generation checklist

When creating a new loop script for a project:

- [ ] `--plan-file` defaults to the project's plan path
- [ ] `--max-runs`, `--max-no-change-runs`, `--max-no-progress-runs` with sane defaults (e.g. 24 / 3 / 3)
- [ ] `--dry-run`, `--allow-dirty`, `--help`
- [ ] Agent auto-detection + `CURSOR_AGENT_BIN`
- [ ] Logs under `.ralph-loop/logs/run-NNN.log`
- [ ] `.ralph-loop/` in `.gitignore` (logs only; plan stays tracked)
- [ ] Prompt matches canonical shape above
- [ ] `chmod +x` the script

## Related

- **Plans and task breakdown** → **ralph-loop-plan** skill
- **Detailed theory and alternatives** → [reference.md](reference.md)
- **Prompt copy-paste template** → [prompt-template.md](prompt-template.md)
- **Script starting point** → [script-template.sh](script-template.sh)
