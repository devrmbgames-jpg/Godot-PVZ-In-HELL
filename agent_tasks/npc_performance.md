# NPC lighting and planning performance

## Task state

Status: **IN_PROGRESS**
- Owner: Codex

### Goal

Remove the measured NPC planning stalls without sacrificing readable code, physical occlusion, circuit state, hazard risk, persistent identity or the owner's level/navigation edits. Reference budget: 16.67 ms at 60 FPS; measure CPU headless separately from rendered FPS.

### Current

Implementation and technical checks are complete. Preparing the Windows QA build; rendered owner QA remains separate.

The owner profiler identifies NpcRouteService.plan / _cost -> NpcLightingService.exposure_at -> DistrictPopulationService.position_for/current and LightCircuitService.state_for/entity_for. Reproduced on main_level: route median 795.412 ms (12 samples); 809 light queries median 768.781 ms (12 batches). The initial frame monitor is contaminated by synchronous benchmark work and is not a valid steady-frame claim.

Cogito source reviewed on 2026-10-04:
- [LightMeter](https://codeberg.org/Phazorknight/Cogito/src/branch/main/addons/cogito/Components/Attributes/cogito_light_meter_attribute.gd): SubViewport texture readback, resize to one pixel, luminance. It warns about cost and supplies move/timer throttles; headless initialization is skipped.
- [Lightzone](https://codeberg.org/Phazorknight/Cogito/src/branch/main/addons/cogito/Components/LightzoneComponent.gd): Area3D enter/exit modifies visibility. Switch component toggles monitoring.

Options: keep a CPU gameplay estimate with batched inputs (chosen); author explicit light volumes (requires level markup and dynamic-shadow policy); viewport sensor (GPU readback per sensor, unsuitable for many route samples). Borrow the principle of bounded work/reusing light context, without copying addon code.

Implementation batches:
1. Reuse scene/world lookups with lifecycle validation; capture authored place positions and light circuit bindings once per perception/planning context. Reject sight candidates by distance/sector before evaluating light.
2. Evaluate graph edges and light samples once per plan; capture damage inputs once. Limit route work per physics frame through a fair queue; preserve interrupted and pending intent behavior.
3. Run the same CPU benchmark, focused GUT regressions, parser, structure checker and connected headless district smoke; record evidence and remaining rendered QA.

### Validation

- Before: utils/benchmark_npc_planning.tscn, .bin/npc-performance-before.log.
- Final CPU benchmark (same headless debug engine/level and route/sample inputs): route median 4.387 ms, p95/max 4.830 ms; 809 light queries median 12.154 ms, p95/max 12.599 ms. Compared with baseline: approximately 181x for the route and 63x for the light-query batch. Log: .bin/npc-performance-after-final.log.
- Scheduled level systems measured directly around main_level._physics_process, 240 samples per phase: morning median/p95/max 3.583/4.625/8.552 ms; day 3.671/4.829/7.774 ms; evening 3.854/4.913/13.968 ms. These exclude renderer and native physics integration and have no comparable uncontaminated pre-change measurement.
- Final relevant GUT: 20 scripts, 234/234 tests, 1491 assertions. .bin/npc-performance-gut-final.log.
- Parser: 14/14 changed/new scripts loaded successfully without script errors/warnings. .bin/npc-performance-parser.log.
- Structure checker: only the pre-existing unrelated agent_tasks/gdscript_readability_cleanup.md missing task-state headings. No new structure findings. git diff --check passes.
- New regression cases cover cache/world replacement, immediate switch/flicker/circuit replacement, physical blockers and query-specific exclusions, origin movement, dark route alternatives, queued goal cancellation/latest destination/fairness. Existing native moving-fire, health reserve, real damage, perception, service, delivery and snapshot tests pass.
- Connected seven-day district smoke: PASS, tests/artifacts/district-20261004-115250423.log. Navigation coverage and retained/reloaded population pass.
- Windows QA build: pending export.

### Owner QA / blockers

- Rendered FPS and original profiler capture remain owner QA; headless CPU numbers cannot establish GPU performance.
- No geometry, navigation bake, dependencies or addon edits are planned.
- Preserve existing AGENTS.md and addons/gecs working changes and addon UID files.
- Rendered checklist: [NPC performance QA](../qa_tasks/npc_performance.md).
