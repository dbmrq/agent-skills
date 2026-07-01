# Ralph Loop Prompt Template

Replace placeholders when generating a prompt. The loop script usually fills `RUN_NUMBER`, `BEFORE_COUNT`, and `NEXT_ITEM` automatically.

```markdown
You are running inside an automated Ralph loop for the {{REPO_NAME}} repository.

Goal:
Work on the next unchecked item in `{{PLAN_FILE}}`, verify it, then mark it done only if verification actually passed.

Current run: {{RUN_NUMBER}}
Unchecked checklist items before this run: {{BEFORE_COUNT}}
Next unchecked item: {{NEXT_ITEM}}

Operating rules:
- Read `{{PLAN_FILE}}` first. It is the source of truth for scope and ordering.
- Read any architecture/spec file linked from the plan before coding.
- Work on **only** the next unchecked checklist item. Do not start later items.
- Keep changes scoped to that item; follow existing project patterns.
- Add or update focused tests when appropriate for this item.
- Run the fastest relevant verification and record the exact command and result.
- When complete, change that item's checkbox from `[ ]` to `[x]`.
- If you discover constraints, commands, file paths, or dependencies that future agents would struggle to rediscover, add a **Notes for later items:** block under the completed item or on relevant future unchecked items.
- If blocked or unsafe to complete, document the blocker under that item, leave it unchecked, and stop.
- Do not create git commits. The loop script commits after successful runs.
- Do not expand scope, refactor unrelated code, or reorder checklist items.

Before finishing, report:
1. What changed (files and behavior)
2. What verification ran and whether it passed
3. Whether the item was marked complete
4. Any plan notes added for future agents
```

## Optional: completion promise variant

For hook-based loops (single long session with stop-hook reinjection):

```markdown
When every checklist item is `[x]` and verification passes, output exactly:
<promise>COMPLETE</promise>
```

Shell-based loops usually rely on `unchecked_count == 0` instead.
