# NPC hazard escape — navigable safe endpoints
Status: **IN_PROGRESS**

## Task state

### Goal

Repair `NpcRouteSolver.refuge` selecting a radial goal outside the connected navmesh,
whose projected route endpoint can remain inside a harmful volume. Keep actual path
planning in `S_NpcRoutePlanning`, movement in existing intent/body owners, and damage intact.
Linked mandatory district-week acceptance: [R26.3](r26_3_npc_behavior_trees.md).

### Current

Checkpoint `63279cf2a0f5b1f9a70bea13ee40759dc19db067` tests point projections around harmful volumes,
requires the destination to clear all overlapping hazards plus arrival tolerance,
and preserves the valid direct exit. The fair planning queue still builds actual paths.
No renderer, physics-body transform, immunity, hazard radius or survival threshold changes.

### Validation

RV-001 P1, Main: `NpcRouteSolver.refuge`, unreachable/clamped unsafe escape endpoint.
Source `a2b1d764b1b316b27df979a8d72917d6deab8ed8`; status ACCEPTED, review repair underway.
Review `588b59c1771d95b4ffba278988ddef0a364013a7` ->
`63279cf2a0f5b1f9a70bea13ee40759dc19db067` found R1 P1 (52s), minimum authored margin.
R1 is merged into RV-001 (same solver/unsafe-endpoint contract). Reproduction211735164
FAIL10/11,85/86; minimum clearance now exceeds arrival tolerance plus rounding.
Identical native bounded-map regressions compare source and current: corrected source
GUT211101065 FAIL6/8,62/64 assertions under `.artifacts/cloud_baseline_588b59c1/`.
Earlier readiness-only fixture failures are not source evidence. Final coherent GUT
**98/690 PASS**: endpoint21133016610/81, performance21134863521/145,
planning21141610441/260, Veil21150089515/127, fire21151427611/77.
Logs are under `.artifacts/godot_agent/`, date20261012. Parser2113001593files PASS;
formatter, strict architecture/domain, structure, staged agent-change and diff checks PASS.
MCP solver reload43 NOT_PASS; fresh native checks independently verify the scripts.

Current district smoke `tests/artifacts/district-20261013-063246721.log` FAIL5/required6;
comparable source week PASS at
`.artifacts/cloud_baseline_588b59c1/tests/artifacts/district-20261013-064942431.log`.
Mortality probe065415654 confirms three original deaths from elemental floor fire.
Critical route probe070242936 shows npc/1's requested goal beyond navmesh and its final
waypoint still inside the moving fire volume. Both preserve the original acceptance.

### Owner QA / blockers

Required headless acceptance and immutable review are pending. No rendered QA is claimed;
the full R26 owner gameplay/visual acceptance remains with its original tasks.

## Acceptance

- Native connected bounded-map escape reaches outside the harmful volume near an edge.
- Endpoint is safe against overlapping hazards, including arrival tolerance.
- Existing direct exits, fire immunity, route queue, cloud and lifecycle tests pass.
- Fresh parser, scoped formatter/static checks and district week pass.
- Immutable-SHA review is collected and accepted findings are resolved.

## Next

Run affected native suites and district week,
then commit and request review from the existing reviewer. R26 acceptance stays open
until its actual smoke passes; this task does not establish cloud causality or waive R26.5.
