# NPC hazard escape — navigable safe endpoints
Status: **IN_PROGRESS**

## Task state

### Goal

Repair `NpcRouteSolver.refuge` selecting a radial goal outside the connected navmesh,
whose projected route endpoint can remain inside a harmful volume. Keep actual path
planning in `S_NpcRoutePlanning`, movement in existing intent/body owners, and damage intact.
Linked mandatory district-week acceptance: [R26.3](r26_3_npc_behavior_trees.md).

### Current

Repair `7de8659ea150953b7b317ff6e5e8e6a9cc328e26` tests point projections around harmful volumes,
requires the destination to clear all overlapping hazards plus arrival tolerance,
and preserves the valid direct exit. The fair planning queue still builds actual paths.
No renderer, physics-body transform, immunity, hazard radius or survival threshold changes.

### Validation

RV-001 P1, Main: `NpcRouteSolver.refuge`, unreachable/clamped unsafe escape endpoint.
Source `a2b1d764b1b316b27df979a8d72917d6deab8ed8`; status FIXED
`7de8659ea150953b7b317ff6e5e8e6a9cc328e26`, GUT21181268711/87 PASS.
Review `588b59c1771d95b4ffba278988ddef0a364013a7` ->
`63279cf2a0f5b1f9a70bea13ee40759dc19db067` found R1 P1 (52s), minimum authored margin.
R1 is merged into RV-001 (same solver/unsafe-endpoint contract). Reproduction211735164
FAIL10/11,85/86; minimum clearance now exceeds arrival tolerance plus rounding.
Targeted re-review `63279cf2a0f5b1f9a70bea13ee40759dc19db067` ->
`7de8659ea150953b7b317ff6e5e8e6a9cc328e26` PASS (18s), no remaining findings.
Architecture/style PASS; reviewer runtime NOT_RUN. Parser2119054912files PASS;
full initial affected batch98/690 plus final targeted11/87 and scoped gates PASS.
Identical native bounded-map regressions compare source and current: corrected source
GUT211101065 FAIL6/8,62/64 assertions under `.artifacts/cloud_baseline_588b59c1/`.
Earlier readiness-only fixture failures are not source evidence. Final coherent GUT
**98/690 PASS**: endpoint21133016610/81, performance21134863521/145,
planning21141610441/260, Veil21150089515/127, fire21151427611/77.
Logs are under `.artifacts/godot_agent/`, date20261012. Parser2113001593files PASS;
formatter, strict architecture/domain, structure, staged agent-change and diff checks PASS.
MCP solver reload43 NOT_PASS; fresh native checks independently verify the scripts.
Final parser2116383133files and repair2119054912files PASS. Mandatory week on
`63279cf2a0f5b1f9a70bea13ee40759dc19db067` FAIL5/required6:
`tests/artifacts/district-20261013-071658349.log`. Default margin0.5 uses the same
calculation after the minimum-margin repair. The independently fixed endpoint defect
does not resolve the full survival failure; mandatory acceptance remains open.

Current district smoke `tests/artifacts/district-20261013-063246721.log` FAIL5/required6;
comparable source week PASS at
`.artifacts/cloud_baseline_588b59c1/tests/artifacts/district-20261013-064942431.log`.
Mortality probe065415654 confirms three original deaths from elemental floor fire.
Critical route probe070242936 shows npc/1's requested goal beyond navmesh and its final
waypoint still inside the moving fire volume. Both preserve the original acceptance.

### Owner QA / blockers

Required headless week acceptance FAIL; immutable review PASS. No rendered QA is claimed;
the full R26 owner gameplay/visual acceptance remains with its original tasks.

## Acceptance

- Native connected bounded-map escape reaches outside the harmful volume near an edge.
- Endpoint is safe against overlapping hazards, including arrival tolerance.
- Existing direct exits, fire immunity, route queue, cloud and lifecycle tests pass.
- Fresh parser, scoped formatter/static checks and district week pass.
- Immutable-SHA review is collected and accepted findings are resolved.

## Next

Continue the original R26 causal diagnosis; linked week acceptance remains FAIL. R26 stays open
until its actual smoke passes; this task does not establish cloud causality or waive R26.5.
