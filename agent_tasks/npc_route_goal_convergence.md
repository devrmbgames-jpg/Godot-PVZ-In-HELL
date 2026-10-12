# NPC route goal convergence after a native endpoint finishes
Status: **IN_PROGRESS**

## Task state

### Goal

Repair `S_NpcRoute` retaining a completed route when the movement goal shifts below
`DEF_District.waypoint_distance` but remains outside actual intent arrival tolerance.
`S_NpcRoutePlanning` keeps the fair queue/frame budget; `S_NpcIntent` and the physical
body retain cursor/control/transform authority. Linked acceptance: [R26.5](r26_5_integration_persistence_validation.md).

### Validation

RV-001/P1 ACCEPTED, source `1b37fcb468e1c0c7d996d1d4df3d7940c933a807`,
`S_NpcRoute._progress_route`: retained goal8.8, current goal9.08, actor8.65,
arrival0.3, waypoint threshold0.5. Native NavigationAgent finishes the retained endpoint;
intent reports blocked/not arrived. Route progression neither queues nor updates the goal.
Native before-fix GUT `.artifacts/godot_agent/gut-20261012-233824760.stdout.log`
FAIL12/13 tests,104/108 assertions; four new queue/goal assertions fail, native setup passes.
Post-fix coherent batch PASS121tests/1640assertions, date20261012 in `.artifacts/godot_agent/`:
endpoint23393373413/111; performance23401922121/145; planning23403546941/260;
Veil23410082415/127; fire23410998611/77; blood23411610210/122; live23412423310/798.
Parser2339533562files, formatter/strict architecture/structure PASS.
Production mortality probe091100283 shows a comparable near-goal state, but this isolated
proof does not establish the complete week failure's cause or waive its survival criterion.

### Current

Scoped repair invalidates a blocked stale goal through the existing due-step owner/queue.
Run focused native reproduction plus route-budget/stable-goal/lifecycle regressions,
parser/formatter/static checks, commit and collect immutable-SHA review. Then run the
unchanged production district week because production route logic changed.

### Owner QA / blockers

Repair SHA/review pending; focused native acceptance PASS. Required week NOT_RUN after repair.
Rendered QA NOT_RUN.
Required full-week acceptance remains open.

## Acceptance

- Native finished stale endpoint queues a reachable path to the current intent goal.
- Unchanged blocked observations retain the new route; stable-route/frame-budget tests pass.
- No body transform/velocity, hazard tuning, arrival threshold, immunity or save-schema change.
- Focused native tests/parser/static gates and immutable review pass.
- Required unchanged district-week survival remains linked and must pass before R26 completion.
