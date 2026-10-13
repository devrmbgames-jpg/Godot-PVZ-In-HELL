# NPC hazard escape — wounded actors retain a viable exit
Status: **DONE**

Linked mandatory acceptance: [R26.3](../r26_3_npc_behavior_trees.md).
Related independent endpoint defect: [native safe endpoints](npc_hazard_escape_navigation.md).

## Task state

### Goal

Do not reject a connected emergency exit merely because estimated exposure exceeds remaining
HP while the actor is already inside a harmful zone. Keep ordinary travel risk, native movement,
damage, immunity, authored radius and mandatory week survival acceptance unchanged.
Require native low-health regression, affected route/cloud suites, parser/static gates,
unchanged district week and immutable repair review.

### Current

Final linked production week `tests/artifacts/district-20261013-112524520.log` **PASS**, wrapper exit0: all seven days,
unchanged survival requirement >=6/8 original residents, night/snapshot/restore/navigation/identity pass.
Code checkpoint `4c60e3dc784352c2fb95ca617cebbafa9a834366`; exact floor-pressure review
BASE `f9888f3c87fb7715d5ab8bdf07b5ef55382c5979` -> TARGET `4c60e3dc784352c2fb95ca617cebbafa9a834366` PASS, no findings.
Wide floor tuning1HP/0.5s is owned by R26.5; radius10m/TTL60s and torso aura4HP unchanged.
Scoped repair code/reviews remain valid ancestors; prior failed weeks below are historical evidence.
No accepted findings or required automated gates remain open in this scoped task.
Rendered gameplay/visual and final balance QA NOT_RUN; these remain in the original R26 tasks.

BASE `c21ac06cc4e71d339e47c2dbe7e3b737fe82d49c` ->
TARGET `5670d3566328a3e831921f2a845276de6a981ee1`.
`NpcRouteSolver.acceptable` accepts finite exposure for active hazard distress; ordinary
travel retains its authored risk budget. Main remains the sole writer.
Immutable review **PASS**, same reviewer, no findings (24s); architecture/style PASS,
reviewer runtime NOT_RUN. Previous collected reviews remain unchanged.

### Review triage

RV-001 P1, Main, source `c21ac06cc4e71d339e47c2dbe7e3b737fe82d49c`,
`NpcRouteSolver.acceptable/plan`: **FIXED**
`5670d3566328a3e831921f2a845276de6a981ee1`, native12/95 and immutable review PASS.
Before-fix bounded mortality probe shows npc/3 hp16 then12, active emergency exit intent,
zero velocity and empty/unreachable route inside floor fire, followed by death on day3.
The native bounded-map regression reproduces rejection of a connected exit at hp0.5.
Ordinary travel still rejects the same exposure when hazard distress is false.

### Validation

Native source GUT `.artifacts/godot_agent/gut-20261012-222812875.*.log`
FAIL11/12,91/92 assertions, specifically unavailable emergency path.
Repair GUT222851263 **PASS12/95**; fresh parser222916972 **PASS2files**;
scoped GDQuest formatter/lint PASS after a test-line formatting correction.
MCP hot reload43 NOT_PASS; fresh native parsing independently verifies.
Mortality evidence `tests/artifacts/district_survival_probe-20261013-082549522.log`:
7200frame diagnostic completed without runtime errors; full week NOT_RUN for this probe.
Pre-repair full week `tests/artifacts/district-20261013-082044400.log` FAIL5/required6.
Affected batch **PASS89tests/627assertions**: endpoint22285126312/95,
budget22294390321/145, planning22301027341/260, cloud22311359915/127.
Wrong cloud file name was rejected before execution; corrected suite above actually ran.
Strict architecture/structure and scoped formatting PASS. Final unchanged week on repair
`tests/artifacts/district-20261013-083125987.log` **FAIL5/required6**, no other runtime errors.
The independent exit rejection is fixed; it does not by itself resolve cumulative floor-fire mortality.

### Next

Scoped task completed and archived. Continue only the original R26 owner-QA gates.

### Owner QA / blockers

Scoped implementation, native verification, immutable reviews and final linked district week PASS.
No scoped blocker remains. Required R26 gameplay/visual acceptance and final floor balance
remain [owner QA](../../qa_tasks/r26_acceptance.md); no rendered QA is claimed.
