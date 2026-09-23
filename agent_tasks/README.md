# Agent Task Notes

Implementation IDs use only `Rxx` / `Rxx.x`. Design documents in `docs/roadmap/` use `ТЗ xx`; these are source specifications and their numbers do **not** imply implementation order.

Canonical mapping/order: [docs/roadmap/README.md](../docs/roadmap/README.md).

Create a file here only for unfinished work too large to recover from `CURRENT_WORK.md`. Completed task files are intentionally removed; verify completion in `task_history.md` instead of recreating them.

Template:

```md
# <task>

Status: planned | active | blocked
Branch: <branch>
Base: <base>

## Goal
One paragraph with acceptance criteria.

## Constraints
Only non-obvious project/version/architecture constraints.

## Steps
- [ ] Small verifiable step
- [ ] Next step

## Decisions
- Decision -> reason

## Validation
- command -> result

## Resume
Next exact file/symbol/command.
```

Rules:
- Update after meaningful milestones.
- Link exact paths/symbols instead of pasting source code.
- Keep facts a fresh agent needs; omit narration and discarded exploration.
- Keep only unfinished tasks here. After completion and validation, move lasting facts into the relevant context/docs, append one short dated line to root `task_history.md`, delete the task file and update its references.
- Preserve active/blocked/planned tasks and this README. Do not archive completed task files here.
- Dependencies must use implementation IDs (`Rxx` / `Rxx.x`), never a `ТЗ` number.
- `Источники` must link the actual design ТЗ files; do not assume `R08 == ТЗ 08`.
- When files/classes move, update the task's `Начать здесь` links in the same structural refactor.
- Milestones/subtasks use cheap static/deterministic validation only; do not run GUT/smoke/runtime suites after every milestone.
- Run the task's documented GUT + headless smoke/runtime validation once near the end of the complete `Rxx` / `Rxx.x` task before marking it complete.
- Early targeted test execution is only for an explicit user request or a concrete blocking bug that cannot be validated statically.
- Runtime budget per complete `Rxx` / `Rxx.x`: at most one GUT invocation and one headless smoke/runtime invocation by default; normally both are reserved for final task validation.
- An early blocking invocation consumes that budget. Additional runtime reruns require explicit user approval.
- Do not add physics smoke coverage for gameplay feel/tuning (ramps, steps, uneven terrain, vehicle/camera/animation feel) unless the user explicitly asks for automated coverage.
- Store/inspect only filtered runtime failures; do not paste full Godot/GUT logs into task/checkpoint context.
