# Ralph Loop Plan Examples

Examples below are **domain-neutral**. Adapt names, paths, and verification commands to the project's stack and existing test tooling.

---

## Good item (right size)

```markdown
- [ ] **5. Implement order creation in the service layer.**  
  Add `OrderService.create` with input validation, idempotency key handling, and persistence through the existing repository interface. Reject invalid line items with typed errors; do not add HTTP handlers yet.  
  Verification: `npm test -- OrderService.test.ts` — covers happy path, validation failures, and duplicate idempotency key.
```

**Why it works:** One cohesive layer, clear boundary ("no HTTP yet"), explicit verification command, named test scope.

---

## Good completed item with notes

```markdown
- [x] **4. Add file storage adapter.**  
  Implemented `StorageAdapter` with read, write, and atomic replace behind an interface.  
  Verification: `pytest tests/test_storage.py` — all pass.  
  **Notes for later items:** Inject via constructor; do not import concrete implementation in domain code. After writes, callers must pass content hash to `SyncState.record` (item 6). Import pipeline (item 7): `list()` → `read()` → `parse()`.
```

**Why it works:** Future agents get API shape, call order, and cross-item dependencies without re-reading the full diff.

---

## Too large → split

**Bad (one run cannot finish reliably):**

```markdown
- [ ] **2. Build the full authentication and user management system.**  
  Registration, login, password reset, OAuth, roles, admin UI, email templates, and session cleanup.
```

**Good (split by layer and wiring):**

```markdown
- [ ] **2. Add user model and password hashing utilities.** ...
- [ ] **3. Implement registration and login service methods.** ...
- [ ] **4. Add HTTP routes and request validation for auth.** ...
- [ ] **5. Add session middleware and protect existing routes.** ...
- [ ] **6. Add password reset flow (service + routes + email stub).** ...
- [ ] **7. Integration test: register → login → access protected route.** ...
```

**Rule:** Split along seams where each piece still **builds and tests independently**.

---

## Too small → merge

**Bad (wastes a full agent run each):**

```markdown
- [ ] **3. Create `ValidationError` type.**
- [ ] **4. Add unit test for `ValidationError`.**
- [ ] **5. Add empty `UserService` class.**
```

**Good:**

```markdown
- [ ] **3. Add user service with validation errors.**  
  Implement `UserService` skeleton, `ValidationError` (and related error types), and unit tests for validation on create/update.  
  Verification: `npm test -- UserService.test.ts` — pass.
```

**Rule:** If items only make sense together in one verification step, merge them.

---

## Integration item (required pattern)

Isolated modules are not enough — dedicate at least one checkbox to **connecting** layers:

```markdown
- [ ] **8. Wire API server to auth and persistence.**  
  Register auth middleware on protected routes. Inject `UserService` and `OrderService` into route handlers via existing DI pattern. Ensure startup loads config and fails fast on missing secrets.  
  Verification: `npm test -- integration/server.test.ts` — covers authenticated and unauthenticated requests; `npm run build` succeeds.
```

**Why it exists:** Without this item, agents often finish "all modules" that never call each other.

---

## Scenario / end-to-end item (required pattern)

```markdown
- [ ] **10. Add end-to-end scenario test for primary user flow.**  
  One test (or serialized suite) covering: create account → create resource → list resources → delete resource. Use test database and HTTP client; no manual steps.  
  Verification: `npm test -- e2e/core-flow.test.ts` — pass in CI-local run.
```

**Why it exists:** Proves the feature works as a whole, not only in unit isolation.

---

## Cleanup item (late plan)

```markdown
- [ ] **12. Consolidate duplicate request handling and remove temp scaffolding.**  
  Merge overlapping validation in handlers into shared helpers. Remove debug endpoints and feature flags added during items 5–9. Document any intentional debt in code comments only where non-obvious.  
  Verification: `npm test` and `npm run lint` — full suite pass.
```

**When to include:** Feature touched many files, multiple agents added one-off patterns, or orchestration logic duplicated across entry points.

---

## Human-only section (correct)

```markdown
## Manual Validation After The Checklist

This section intentionally has no checkboxes — the Ralph loop script must not invoke agents for these steps.

- Deploy to staging and smoke-test critical flows in a production-like environment
- Review UX with design or product (accessibility, copy, layout)
- Run load or soak test if the feature is latency- or throughput-sensitive
- Approve production release per team process
```

**Never use `- [ ]` here** — the loop script treats every checkbox as an agent task.

---

## Ralph intro (minimal, for agents)

```markdown
## How this plan is used (Ralph loop)

An automated loop runs a **fresh agent** on each unchecked item in **Implementation Checklist**, in order. One item per run. Each agent verifies its work before marking `[x]`. **Notes for later items** under completed tasks pass discoveries to later runs. Human-only steps live in **Manual Validation** (no checkboxes).
```

---

## Plan amendment (when structure must change mid-loop)

Do not silently renumber or reorder during a loop. Append at the bottom:

```markdown
## Plan amendment (after run 9)

**Structural:** Item 6 is too large — on next human edit, split into 6a (service) and 6b (HTTP wiring).

**Blocker:** Run 9 stopped on item 6 — two valid schema designs; needs human choice between normalized vs denormalized orders. See blocker note under item 6. Item remains unchecked.
```

---

## Verification line patterns

Use whatever the repo already uses. Be **specific**:

| Weak | Strong |
|------|--------|
| "Run tests" | `` `pytest tests/unit/test_orders.py` — pass `` |
| "Manual test" | *(move to Manual Validation section)* |
| "Lint clean" | `` `npm run lint` — zero errors `` |
| "Works" | `` `curl -X POST ...` returns 201; `npm test -- e2e` pass `` |

Pick the **fastest check that proves the item** — not the full CI suite unless the item requires it.
