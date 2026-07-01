# Ralph Loop — Reference

## Theory

### Problem Ralph solves

Long single-session agent runs suffer from:

- **Context rot** — early decisions get buried; later turns contradict earlier ones
- **False completion** — model declares done without running verification
- **Unbounded scope** — one prompt becomes a whole feature without checkpoints

Ralph externalizes memory to **files and git** and bounds each turn to **one task**.

### Ralph vs ReAct vs one-shot

| Pattern | Mechanism | Memory |
|---------|-----------|--------|
| One-shot | Single prompt, single response | Context window only |
| ReAct | Reason + act in one session | Growing transcript |
| Ralph loop | Repeated fresh sessions | Disk + git between runs |

### Two orchestration styles

**External shell loop** (Cursor CLI, custom bash):

```bash
while unchecked_items remain; do
  agent -p "$PROMPT"
  commit if changed
  break if guardrails trip
done
```

**Stop-hook loop** (Claude Code Ralph plugin):

- Same prompt reinjected when agent tries to exit
- Hook blocks exit unless completion promise detected
- Work persists in files within one session ID

For Cursor, prefer **external shell loops** — each `agent -p` is a fresh context.

### State layer components

| Artifact | Purpose |
|----------|---------|
| Plan markdown | Ordered checklist + specs + agent notes |
| Architecture/spec doc | Stable design reference linked from plan |
| Git history | Auditable per-run diffs (`ralph-loop: run N` commits) |
| Run logs | `.ralph-loop/logs/` — agent stdout for debugging |
| Test suite | Objective progress gate |

### Success factors

1. **Machine-verifiable items** — each checkbox has a verification clause
2. **Right-sized tasks** — one agent run each (see ralph-loop-plan skill)
3. **Integration tasks** — not only isolated units
4. **Guardrails** — max runs, no-progress detection
5. **Plan enrichment** — agents pass knowledge forward via notes

## Anti-patterns

| Anti-pattern | Fix |
|--------------|-----|
| One checkbox for "build entire product" | Split per ralph-loop-plan sizing guide |
| No verification in items | Add explicit commands or pass/fail criteria |
| Agent commits + script commits | Single commit owner |
| Parsing any `- [ ]` in doc (including examples) | Use numbered checklist section or strict regex |
| Human tasks as checkboxes | Script will invoke agents for them; use plain headings |
| Ignoring no-progress runs | Agent may thrash; stop and fix plan |

## Alternatives and complements

- **Cursor `/loop` skill** — Recurring prompts in one session; not the same as Ralph (no fresh context per iteration). Use for monitoring, not multi-hour implementation.
- **CI after loop** — Run full CI when plan completes; optional checkbox near end.
- **Parallel agents** — Only for independent items; Ralph is inherently serial. Note dependencies in plan.

## Further reading

- [What Is the Ralph Technique?](https://ralphloop.sh/blog/what-is-the-ralph-technique/)
- [Ralph Loop vs One-Shot Prompting](https://ralphloop.sh/blog/ralph-loop-vs-one-shot-prompting/)
- [Anthropic Claude Ralph Loop plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop)
