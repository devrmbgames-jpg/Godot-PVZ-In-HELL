# NPC route goal convergence after endpoint completion or moving danger
Status: **DONE**

## Task state

### Goal

Repair `S_NpcRoute` retaining a completed or newly unsafe escape endpoint when the movement
goal shifts below `DEF_District.waypoint_distance` but remains outside actual arrival tolerance.
`S_NpcRoutePlanning` keeps the fair queue/frame budget; `S_NpcIntent` and the physical
body retain cursor/control/transform authority. Linked acceptance: [R26.5](../r26_5_integration_persistence_validation.md).

### Validation

RV-001 immutable review PASS, no findings,34s: BASE
`1b37fcb468e1c0c7d996d1d4df3d7940c933a807` -> TARGET
`19a080981bcec44fb2be2c8725892129db6f200a`; architecture/style PASS, reviewer validation NOT_RUN.
Historical RV-001 week094309939 FAIL4/6; endpoint-safety week111311881 FAIL5/6,
night/snapshot/restore PASS; shutdown4ObjectDB/2Resource retention DEFERRED.
RV-001/P1 FIXED `19a080981bcec44fb2be2c8725892129db6f200a`, source `1b37fcb468e1c0c7d996d1d4df3d7940c933a807`,
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
RV-002/P1 FIXED `78e9b826470dce320bf9999f495ed0c05ab8c8f5`, source
`2da4a456d66a137e5316af2ba87355fa2cc94a08`
(production code identical to reviewed `a030253a2ffcb7bf2cc4b4e758629c6dc45225e3`):
`S_NpcRoute._progress_route` retains a newly unsafe escape endpoint until native stopping
because the replacement is only0.32m away, below waypoint0.5. Distinct from RV-001's
already-finished endpoint; no duplicate connected-candidate finding is created.
Readonly `.artifacts/r26_motion_burst-20261013.log`3000frames, native exit0, full week NOT_RUN:
NPC4 has full desired/avoidance1.9197m/s; frames1827/1852/1877 show blocked/not-arrived,
zero controller and braking at the old goal while a new refuge0.32m away remains unapplied.
Native regression GUT20261013-010833652 FAIL14/15 tests152/156assertions:
old goal(8,0,3.9), source(8,0,-2)->(8,0,-1.68), replacement(8,0,4.22);
native route still unfinished, all setup assertions PASS; four queue/goal assertions fail.
Repair checks effective endpoint safety in the existing due-step owner and queues only a changed
goal whose retained refuge is unsafe. Still-safe small shifts keep the original tolerance.
Affected batch PASS121tests/918assertions, logs date20261013 under `.artifacts/godot_agent/`:
endpoint01093400715/156; performance01104856721/145; scheduling01110479749/291;
Veil01113217215/127; fire01114130311/77; blood01114743110/122.
Parser0111555603files, formatter3files/strict architecture/structure PASS.
Unchanged reconstruction/schema gates remain valid; no fields/reset/save authority changed.

### Current

Final linked production week `tests/artifacts/district-20261013-112524520.log` **PASS**, wrapper exit0: all seven days,
unchanged survival requirement >=6/8 original residents, night/snapshot/restore/navigation/identity pass.
Code checkpoint `4c60e3dc784352c2fb95ca617cebbafa9a834366`; exact floor-pressure review
BASE `f9888f3c87fb7715d5ab8bdf07b5ef55382c5979` -> TARGET `4c60e3dc784352c2fb95ca617cebbafa9a834366` PASS, no findings.
Wide floor tuning1HP/0.5s is owned by R26.5; radius10m/TTL60s and torso aura4HP unchanged.
Scoped repair code/reviews remain valid ancestors; prior failed weeks below are historical evidence.
No accepted findings or required automated gates remain open in this scoped task.
Rendered gameplay/visual and final balance QA NOT_RUN; these remain in the original R26 tasks.

RV-001 reviewed repair remains FIXED. RV-002 endpoint-safety retirement repair committed;
affected native/static checks PASS; collected immutable review PASS, historical unchanged full week FAIL5/6.
Review BASE `2da4a456d66a137e5316af2ba87355fa2cc94a08` -> TARGET
`78e9b826470dce320bf9999f495ed0c05ab8c8f5`, same reviewer,25s, no findings.
Architecture/style PASS; reviewer validation NOT_RUN. RV-002 resolved, no pending accepted finding.
Historical reviewed production week111311881 FAIL5/required6; linked
[connected refuge candidates](npc_hazard_escape_connected_candidates.md) RV-001..004 remain FIXED.

### Owner QA / blockers

Scoped implementation, native verification, immutable reviews and final linked district week PASS.
No scoped blocker remains. Required R26 gameplay/visual acceptance and final floor balance
remain [owner QA](../../qa_tasks/r26_acceptance.md); no rendered QA is claimed.

## Acceptance

- Native finished stale endpoint queues a reachable path to the current intent goal.
- Unchanged blocked observations retain the new route; stable-route/frame-budget tests pass.
- No body transform/velocity, hazard tuning, arrival threshold, immunity or save-schema change.
- Focused native tests/parser/static gates and immutable review pass.
- Required unchanged district-week survival remains linked and must pass before R26 completion.
