# Agent tasks

This directory contains durable state only for work that is long-running, interruptible, explicitly tracked, or Feature-sized.

Implementation IDs use `Rxx` / `Rxx.x`. Design specifications under `docs/roadmap/` use `ТЗ xx`; their numbers do not imply implementation order.

Canonical queue/status index: [CONTEXT.md](CONTEXT.md).  
Canonical design-to-implementation mapping: [docs/roadmap/README.md](../docs/roadmap/README.md).

## Right-sized task policy

- **Fix** — no task file.
- **Task** — reuse an existing task artifact when useful; create one only for genuinely interruptible/long-running work.
- **Feature** — durable task/router is required.
- Do not create a second plan when a roadmap/task already owns the work.
- For a large task, the root file remains the authoritative router/state; detailed milestones may live in `agent_tasks/<task_slug>/`.
- Supporting specs/inventories use `SUPPORT` and never compete with the owner task for status/current/next-step authority.

## Status vocabulary

- `PLANNED`
- `IN_PROGRESS`
- `DEFERRED`
- `BLOCKED`
- `OWNER_QA`
- `DONE`
- `SUPPORT`

## Authoritative task state

Each executable task/router should expose a compact control block near the top:

```md
Status: **PLANNED | IN_PROGRESS | DEFERRED | BLOCKED | OWNER_QA | DONE**

## Task state

### Goal
One short outcome.

### Constraints / acceptance
Only constraints that materially affect implementation.

### Milestones
- [ ] Small coherent stage.

### Decisions
Durable decisions/invariants only.

### Current
Exact checkpoint and one next step.

### Validation
Checks actually run and their result.

### Owner QA / blockers
Only remaining manual/external verification.

### Review
Optional material findings:
| ID | Severity | Finding | State | Evidence / decision |
| R1 | BUG | ... | OPEN / FIXED / ACCEPTED / FALSE_POSITIVE | ... |
```

Historical details may remain below the control block as evidence/reference, but the control block is authoritative for status/current/next action.

## Runtime budget

Do not run GUT/smoke after every milestone. For a complete large `Rxx` / `Rxx.x`, normally reserve one relevant GUT invocation and one relevant headless smoke/runtime invocation near completion unless the task explicitly requires otherwise.

Completed work is summarized in [task_history.md](../task_history.md). Do not recreate removed completed task files merely to satisfy the new format.
