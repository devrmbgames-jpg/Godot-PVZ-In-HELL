# NPC hazard escape — wounded actors retain a viable exit
Status: **IN_PROGRESS**

Linked mandatory acceptance: [R26.3](r26_3_npc_behavior_trees.md).
Related independent endpoint defect: [native safe endpoints](npc_hazard_escape_navigation.md).

## Task state

### Goal

Do not reject a connected emergency exit merely because estimated exposure exceeds remaining
HP while the actor is already inside a harmful zone. Keep ordinary travel risk, native movement,
damage, immunity, authored radius and mandatory week survival acceptance unchanged.
Require native low-health regression, affected route/cloud suites, parser/static gates,
unchanged district week and immutable repair review.

### Current

BASE `c21ac06cc4e71d339e47c2dbe7e3b737fe82d49c`; repair not yet committed.
`NpcRouteSolver.acceptable` accepts finite exposure for active hazard distress; ordinary
travel retains its authored risk budget. Main remains the sole writer.
Review REVIEW_PENDING until the immutable repair checkpoint is collected; previous reviews remain collected.

### Review triage

RV-001 P1, Main, source `c21ac06cc4e71d339e47c2dbe7e3b737fe82d49c`,
`NpcRouteSolver.acceptable/plan`: **ACCEPTED / repair validated**.
Current bounded mortality probe shows npc/3 hp16 then12, active emergency exit intent,
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
Strict architecture/structure and scoped formatting PASS; final unchanged week is running.

### Next

Commit coherent repair, reuse the existing reviewer against full SHAs, and collect the
unchanged district week. Do not claim the broader mortality issue resolved
until the required week actually passes.

### Owner QA / blockers

Required review and full week are pending. No rendered gameplay or visual QA ran.
