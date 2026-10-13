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
Initial implementation `32ddcee3f696eb9d48e320091e9b8ed6f0c414ea` passed the relevant batch.
Collected review found RV-002 map invalidation ordering; native reproduction confirms it.
Map retirement repair and targeted review PASS; unchanged production week FAIL5/required6.
Native moving-source reproduction reveals RV-003: shifted island projection escapes exact-point
rejections. A bounded transient direction cursor now advances after actual failed planning,
preserving the ordinary first-choice behavior; danger/map/reconstruction reset both feedback fields.
Full affected verification and immutable review PASS; latest unchanged week FAIL5/required6.
Readonly cursor/cache probe confirms NPC3 cursor2, two failed points and a reachable moving
route before death; NPC1/4 also have reachable moving routes. Native RV-004 then proves
successful retry-goal drift while the actor advances. Solver now retains that already-planned
world goal only while map/revision and safety remain valid. Moving danger invalidation is covered.
Latest bounded probe1055116147200frames PASS: NPC3 cursor1, retained goal and reachable physical
movement; NPC1/4 also move on reachable routes, without combat. Deaths remain4/day1,3/day3,1/day4.
Full week105104090 FAIL5/6. Remaining mortality belongs to R26.5; required survival remains unwaived.

### Validation

RV-001/P1 FIXED `32ddcee3f696eb9d48e320091e9b8ed6f0c414ea`, source
`19a080981bcec44fb2be2c8725892129db6f200a`,
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
Initial review BASE `19a080981bcec44fb2be2c8725892129db6f200a` -> TARGET
`32ddcee3f696eb9d48e320091e9b8ed6f0c414ea`: architecture FAIL (R1), style PASS,
reviewer validation NOT_RUN, approximately51s. Same reviewer; no duplicate review.
RV-002/P1 FIXED `c02213ef77d055b725cb221adf0b7cf48e89b77a`, source TARGET above,
`S_NpcRoutePlanning._process_pending`:
short delta + changed goal publishes new map before interval invalidation, retaining old
failures. Distinct cache-lifetime defect; main confirmed against current HEAD.
Native new-map + changed-goal + delta0.2 reproduction: GUT20261013-000541454
FAIL13/14 tests128/129 assertions, only old-feedback retirement fails; native planning passes.
After repair relevant batch PASS103tests/1549assertions, logs date20261013:
endpoint00061437214/129, performance00064827521/145, scheduling00070452749/291,
live00073288110/822, participation0007470959/162. Parser0008012742files PASS;
formatter2files/strict architecture/structure/diff checks PASS.
First targeted re-review PASS: BASE `32ddcee3f696eb9d48e320091e9b8ed6f0c414ea`
-> TARGET `c02213ef77d055b725cb221adf0b7cf48e89b77a`, same existing reviewer,11s.
RV-002 RESOLVED, no material findings; architecture/style PASS, reviewer validation NOT_RUN.
RV-003/P1 FIXED `526780a07441cb30b2812d9bfe209583096744cc`, source
`c02213ef77d055b725cb221adf0b7cf48e89b77a`,
`NpcRouteSolver.refuge`: moving source shifts the failed island projection outside waypoint
tolerance and repeatedly restarts first-choice selection instead of progressing to alternatives.
Full readonly probe `tests/artifacts/district_survival_probe-20261013-101155950.log`
FAIL5/6: floor-fire deaths npc4/day2, npc3/day3, npc1/day4; npc3 empty route while
safe candidates2..6 have complete native paths. No other runtime errors.
Native moving-source0.6m regression GUT20261013-001554655 FAIL13/14 tests126/129:
island reselected and two route assertions fail, setup passes. Final cursor repair batch
PASS139tests/1904assertions, logs date20261013: endpoint00184336414/134,
performance00174188921/145, scheduling00175815949/291, Veil00182653015/127,
fire00183567611/77, blood00184180210/122, live00185096310/846,
participation0019051879/162. Parser0019183716files, formatter6files,
strict architecture/structure/persistence PASS. Native map retirement and fresh/reused
all-twelve reconstruction verify both feedback fields. Immutable review PASS, no findings:
BASE `c02213ef77d055b725cb221adf0b7cf48e89b77a` -> TARGET
`526780a07441cb30b2812d9bfe209583096744cc`, same reviewer,100s.
Architecture/style PASS; reviewer validation NOT_RUN. RV-003 resolved; latest full week FAIL5/6.
RV-004/P1 FIXED `a030253a2ffcb7bf2cc4b4e758629c6dc45225e3`, source
`526780a07441cb30b2812d9bfe209583096744cc`,
`NpcRouteSolver.refuge`: retry direction rotates relative to the advancing actor even after
native planning succeeded; safe goal(8.43096,0,-5.123841) moves to(6.308368,0,-5.259321)
after actor advances0.75m, despite unchanged hazard/map. Native GUT20261013-004359199
FAIL13/14 tests134/135 assertions, only new retained-goal assertion fails; actual route setup PASS.
Repair retains the existing successful goal for retries, rejects it when a moving hazard covers
it or native map/revision changes, without new state/path queries/intent writes.
Current affected batch PASS120tests/899assertions, logs date20261013:
endpoint00453355414/137; performance00472147421/145; scheduling00473768549/291;
Veil00480606215/127; fire00481520311/77; blood00482130710/122. Parser0048294713files
and formatter3files/strict architecture/structure PASS. Unchanged lifecycle suites retained
from cursor checkpoint: live10/846 and participation9/162 PASS; no lifecycle/schema write changed.
Targeted review PASS, no findings: BASE `526780a07441cb30b2812d9bfe209583096744cc`
-> TARGET `a030253a2ffcb7bf2cc4b4e758629c6dc45225e3`, same reviewer,35s.
Architecture/style PASS; reviewer validation NOT_RUN. RV-004 resolved; unchanged full week FAIL5/6.

### Owner QA / blockers

Unchanged week on reviewed retained-goal repair `tests/artifacts/district-20261013-105104090.log`
FAIL5/required6 (prior map repair also5, initial4); night/snapshot/restore pass, no other runtime errors.
Readonly full-week probe101155950 also FAIL5/6; scoped repair must not waive required survival.
Post-cursor bounded probe `district_survival_probe-20261013-102505182.log`7200frames
native runtime PASS (full week NOT_RUN): NPC3's cursor/cache selects a connected native path;
all three original deaths still occur while earlier critical samples show physical movement.
Two extra diagnostic fields compile/run natively; formatter1file PASS, no gameplay mutation.
Rendered permission pending; [owner QA](../qa_tasks/r26_acceptance.md) NOT_RUN.

## Acceptance

- Actual failed island projection yields a reachable safe candidate through existing fair queue.
- Failed feedback is bounded and cleared on hazard exit, native map change and reconstruction.
- Stable paths, frame budget, immunity, overlapping hazards and other route lifetimes pass.
- Native parser/relevant GUT/static and immutable review pass; required district week stays linked.
