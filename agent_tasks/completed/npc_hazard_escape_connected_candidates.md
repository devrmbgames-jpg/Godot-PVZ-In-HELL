# NPC hazard escape — connected candidates after native path failure
Status: **DONE**

## Task state

### Goal

Use actual failed route feedback to skip disconnected refuge projections while keeping
path building in the fair `S_NpcRoutePlanning` queue. The projection itself may be safe
on a separate navmesh region; a reachable alternative must remain available.
Linked mandatory survival acceptance: [R26.5](r26_5_integration_persistence_validation.md).

### Current

RV-001..004 FIXED with native before/after regressions and collected immutable reviews.
Failed-refuge feedback is bounded, retired on danger/map/reconstruction, and successful
retry goals remain stable while native map/revision and hazard safety stay valid.
Path construction retains the existing fair queue; no alternate movement/physics authority.
Final linked production week `tests/artifacts/district-20261013-112524520.log` **PASS**, wrapper exit0: all seven days,
unchanged survival requirement >=6/8 original residents, night/snapshot/restore/navigation/identity pass.
Code checkpoint `4c60e3dc784352c2fb95ca617cebbafa9a834366`; exact floor-pressure review
BASE `f9888f3c87fb7715d5ab8bdf07b5ef55382c5979` -> TARGET `4c60e3dc784352c2fb95ca617cebbafa9a834366` PASS, no findings.
Wide floor tuning1HP/0.5s is owned by R26.5; radius10m/TTL60s and torso aura4HP unchanged.
Scoped repair code/reviews remain valid ancestors; prior failed weeks below are historical evidence.
No accepted findings or required automated gates remain open in this scoped task.
Rendered gameplay/visual and final balance QA NOT_RUN; these remain in the original R26 tasks.

### Validation

Post-cursor bounded `district_survival_probe-20261013-102505182.log`7200frames native PASS
(full week NOT_RUN): NPC3 selects a connected path; earlier critical samples show physical
movement but the three original deaths still occur. Post-retained-goal bounded probe105511614
also PASS7200frames (week NOT_RUN): NPC3 cursor1, retained reachable goal; NPC1/4 move without
combat. Historical week105104090 FAIL5/6; earlier101155950 FAIL5/6 and initial4/6.
Diagnostic fields compile/run natively; scoped formatter PASS, no gameplay mutation.
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

Scoped implementation, native verification, immutable reviews and final linked district week PASS.
No scoped blocker remains. Required R26 gameplay/visual acceptance and final floor balance
remain [owner QA](../../qa_tasks/r26_acceptance.md); no rendered QA is claimed.

## Acceptance

- Actual failed island projection yields a reachable safe candidate through existing fair queue.
- Failed feedback is bounded and cleared on hazard exit, native map change and reconstruction.
- Stable paths, frame budget, immunity, overlapping hazards and other route lifetimes pass.
- Native parser/relevant GUT/static and immutable review pass; required district week stays linked.
