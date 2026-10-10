# Warehouse navigation — align acceptance with the current route contract

Status: **IN_PROGRESS**

Found during [district integration](district_release_validation.md); its required connected
smoke remains open. This independent validator defect does not waive district acceptance.

## Task state

### Goal

Validate native coverage/connectivity and authored shade-route segments without requiring
an unused legacy junction graph or changing owner geometry/navigation assets.

### Current

`district` smoke fails before day one: 43 covered points / 42 connected counter routes,
but `_graph_failures` demands 13 legacy junctions form a strongly connected graph;
all authored `neighbours` are empty. Runtime `NpcRouteSolver` uses navmesh, ordered
`DEF_District.shade_route` in both directions and native fallback for an empty route.
No gameplay consumer traverses `DEF_DistrictPlace.neighbours`; Content Doctor validates
only any explicitly supplied references. Requiring that legacy graph is an obsolete gate.

Comparable source baseline: `e0758d54aca744e28e7969c46713458f817a6c72`; current checkpoint:
`e73ae44da98a46d9e3a67101c716f8178acb99ad`. Utility, district definition/place, route solver
and main_level are identical across these commits. This is source equivalence, not a claimed
baseline engine run or a regression introduced by scanner cleanup.

Repair implemented: preserve coverage/counter-path checks and validate actual configured
shade-route references/adjacent segments in both directions. Native district smoke now
reports 43 points / 42 counter routes / 0 navigation failures and has entered day three;
the run is still live, so multi-day PASS is not claimed. Source review is pending.

### Validation

FAIL: `utils/run_smoke.ps1 -Name district -GodotPath .bin/Godot_v4.7.1-stable_win64_console.exe -Frames 20000`;
`tests/artifacts/district-20261011-003916570.log`: disconnected legacy graph from `pvz_entry`.
That run never reached multi-day acceptance.
PASS: focused GUT8/8, 15 asserts (`gut-20261010-144709674`), native parser2/2
(`parsefiles-20261010-144647350`), incremental formatter/lint, strict architecture,
project structure and staged agent-change guard. Live final script diagnostics checked/clean.
RUNNING: district smoke after repair; immutable-SHA review NOT_RUN.

### Owner QA / blockers

No rendered/visual QA is required for this bounded validation fix. Preserve geometry,
navmesh, placed IDs and exported data. Do not restore a runtime graph to satisfy an old check.

## Scope / acceptance

- `utils/warehouse_navigation_checks.gd` and `tests/gut/test_warehouse_navigation.gd` only.
- Retain baked polygons, transformed coverage, bounded map synchronization, complete
  counter paths, layer filtering and native RID cleanup.
- Validate configured shade-route references and each adjacent native segment in both
  directions. Empty shade_route retains the solver's navmesh fallback; unused legacy
  junctions do not require invented edges.
- Focused tests keep off-mesh/disconnected-island failures, prove unused junctions valid,
  reject unknown shade-route IDs and verify connected/disconnected configured routes.
- Actual formatter/parser/GUT, district smoke and immutable-SHA review/triage before DONE;
  archive this record with incoming links updated. Full district acceptance remains separate.

### Next

Collect the live district smoke result, review the committed repair on immutable SHAs, and
triage findings. Other district acceptance stays open; do not change assets to force PASS.
