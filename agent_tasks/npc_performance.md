# NPC lighting and planning performance

## Task state

Status: **DONE**
- Owner: Codex

### Goal

Remove the measured NPC planning stalls with simple authored routes and manually placed light zones, preserving physical sight occlusion, circuit state, hazard risk, persistent identity and the owner's geometry/navigation. Reference budget: 16.67 ms at 60 FPS; measure CPU headless separately from rendered FPS.

### Current

Completed in db5f6f5d with the owner's final choices: fixed shade passage and manually placed Area3D light volumes. Graph route search, sorting, light sampling along routes and light-source ray casting are removed. Only a bounded nearest entry/exit check on four authored shade points remains. Routes are retained until destination/navmesh/risk changes. Six room zones follow the owner's DebugMarkers, leaving geometry and navmesh untouched. Static volume geometry is captured once; a moving player light uses moving_source and the same zone API. Validation and the Windows build are complete.

Exported shutdown diagnostics identified active footstep OGG playback retained at forced exit, not NPC caches. CharacterFootstepper stops native playbacks and clears streams on exit, restoring the pool for reattachment. Final packaged menu/main-level stderr has no ObjectDB/resource leaks, only the existing Windows certificate-store warning. Addon source stays unchanged.

The owner profiler identifies NpcRouteService.plan / _cost -> NpcLightingService.exposure_at -> DistrictPopulationService.position_for/current and LightCircuitService.state_for/entity_for. Reproduced on main_level: route median 795.412 ms (12 samples); 809 light queries median 768.781 ms (12 batches). The initial frame monitor is contaminated by synchronous benchmark work and is not a valid steady-frame claim.

Cogito source reviewed on 2026-10-04:
- [LightMeter](https://codeberg.org/Phazorknight/Cogito/src/branch/main/addons/cogito/Components/Attributes/cogito_light_meter_attribute.gd): SubViewport texture readback, resize to one pixel, luminance. It warns about cost and supplies move/timer throttles; headless initialization is skipped.
- [Lightzone](https://codeberg.org/Phazorknight/Cogito/src/branch/main/addons/cogito/Components/LightzoneComponent.gd): Area3D enter/exit modifies visibility. Switch component toggles monitoring.

Final choice authorized by the owner: authored light volumes, like Cogito Lightzone. The level is static; the only future dynamic light is the player's Area. Volume boundaries represent lighting; no dynamic shadow calculation from items is required. Viewport readback and per-lamp ray casting are excluded. Physical rays remain for sight, independent of illumination. No addon code is copied.

Completed implementation batches:
1. Reuse scene/world lookups with lifecycle validation; capture authored place positions and light circuit bindings once per perception/planning context. Reject sight candidates by distance/sector before evaluating light.
2. Replace graph evaluation with the ordered shade passage and one native path. Capture effective damage inputs once; allow only one local hazard bypass. Limit route work per physics frame through a fair queue; preserve interrupted and pending intent behavior.
3. Run the same CPU benchmark, focused GUT regressions, parser, structure checker and connected headless district smoke; record evidence and remaining rendered QA.

### Validation

- Before: utils/benchmark_npc_planning.tscn, .bin/npc-performance-before.log.
- Final authored-route/manual-volume CPU benchmark (same headless debug engine/level and route/sample inputs): route median 0.236 ms, p95/max 0.394 ms; 809 light queries median 9.012 ms, p95/max 10.629 ms. Compared with baseline: approximately 3370x for this route and 85x for this light-query batch. Six light zones/four shade points confirmed. Log: .bin/npc-manual-light-final-benchmark.log. The illumination model intentionally changes to author-controlled volumes.
- Scheduled level systems measured directly around main_level._physics_process, 240 samples per phase: morning median/p95/max 6.089/7.141/28.172 ms; day 6.604/7.763/20.264 ms; evening 6.581/7.473/11.756 ms. These exclude renderer and native physics integration; no uncontaminated comparable pre-change frame measurement exists. External editor/game CPU load was not controlled. Occasional maxima exceed the reference frame budget and require the owner's rendered profiler follow-up.
- Relevant GUT: 21 scripts, 243/243 tests, 1569 assertions (.bin/npc-light-zone-gut.log). Final changed-volume/perception/native route surface: 3 scripts, 53/53 tests, 295 assertions (.bin/npc-manual-light-final-focused.log). Audio/zone lifecycle: 24/24, 152 assertions before the final static geometry cache.
- Parser: 16/16 changed/new scripts, then the final eight-script batch including cached volumes and native audio stop, loaded without script errors/warnings. .bin/npc-manual-light-parser.log and .bin/npc-manual-light-final-parser.log.
- Structure checker at optimization closeout: only the pre-existing agent_tasks/gdscript_readability_cleanup.md missing task-state headings. The owner subsequently authorized that task; its headings are corrected when starting it. No new structure findings. git diff --check passes.
- Updated regressions cover cache/world replacement, immediate switch/flicker/circuit replacement, manual zone boundaries and movement/removal, ordered shade travel in both directions, unchanged route retention, unsafe-route invalidation, and queued cancellation/latest destination/fairness. Physical blockers continue to be tested by the sight suite. Existing native moving-fire, health reserve, real damage, service, delivery and snapshot tests are included.
- Connected seven-day district smoke: PASS, tests/artifacts/district-20261004-124034475.log. Navigation coverage and retained/reloaded population pass with manual volumes and static shade routing.
- Windows QA build: PASS, [.export/windows/20261004-024729Z-db5f6f5d-npc-authored-light-routes/PVZInHell.exe](../.export/windows/20261004-024729Z-db5f6f5d-npc-authored-light-routes/PVZInHell.exe). Menu and main level each passed 120 headless startup frames; both stdout and stderr checked for script errors and ObjectDB/resource leaks. [.export/LATEST.cmd](../.export/LATEST.cmd) points to this build. Build metadata records db5f6f5d and the preserved pre-existing dirty files.

### Owner QA / blockers

- Rendered FPS and original profiler capture remain owner QA; headless CPU numbers cannot establish GPU performance.
- Only additive light-zone nodes are authored in main_level, using existing DebugMarkers bounds. Geometry, navigation bake, dependencies and addons are preserved.
- Preserve existing AGENTS.md and addons/gecs working changes and addon UID files.
- Rendered checklist: [NPC performance QA](../qa_tasks/npc_performance.md).
