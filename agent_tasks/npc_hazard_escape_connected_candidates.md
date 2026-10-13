# NPC hazard escape — connected candidates after native path failure
Status: **IN_PROGRESS**

## Task state

### Goal

Use actual failed route feedback to skip disconnected refuge projections while keeping
path building in the fair `S_NpcRoutePlanning` queue. The projection itself may be safe
on a separate navmesh region; a reachable alternative must remain available.
Linked mandatory survival acceptance: [R26.5](r26_5_integration_persistence_validation.md).

### Current

Main repairs bounded derived `C_NpcRoute` feedback: planning records a failed refuge;
point selection skips it; route lifecycle clears feedback after danger/map invalidation;
native reconstruction clears the transient field. No new goal/physics authority or tuning.
Focused reproduction plus full relevant route/cache/lifecycle batch PASS. Commit and collect
immutable review, then run the unchanged production district week.

### Validation

RV-001/P1 ACCEPTED, source `19a080981bcec44fb2be2c8725892129db6f200a`,
`NpcRouteSolver.refuge`/`S_NpcRoutePlanning`: failed projected island is selected again,
even when other safe candidates have complete native paths.
Readonly production probe `tests/artifacts/district_survival_probe-20261013-095128201.log`
7200frames (full week NOT_RUN) shows npc3's safe candidate1 endpoint gap2.945m and
complete safe candidates2..6. Actual route empty, blocked, followed by floor-fire death.
Native disconnected-region regression on source: GUT235422505 FAIL13/14 tests,
118/121 assertions; native map/island/initial failed planning setup passes, three new
alternative/route assertions fail. Logs date20261012 under `.artifacts/godot_agent/`.
Post-fix full relevant batch PASS131tests/1842assertions, date20261012:
endpoint23575967614/127; performance23581288821/145; planning23582909541/260;
Veil23585543315/127; fire23590457311/77; blood23591069810/122; live23591884710/822;
participation2359330749/162. Native hazard-exit/map-handoff feedback retirement and
fresh/reused all-twelve body reconstruction verified. Parser2358322816files and actual
probe compilation/runtime PASS; formatter7files/strict architecture/structure/persistence PASS.
Fix SHA/immutable review pending coherent commit.

### Owner QA / blockers

Required unchanged week previously FAIL4/required6; scoped repair must not waive it.
Rendered permission pending; [owner QA](../qa_tasks/r26_acceptance.md) NOT_RUN.

## Acceptance

- Actual failed island projection yields a reachable safe candidate through existing fair queue.
- Failed feedback is bounded and cleared on hazard exit, native map change and reconstruction.
- Stable paths, frame budget, immunity, overlapping hazards and other route lifetimes pass.
- Native parser/relevant GUT/static and immutable review pass; required district week stays linked.
