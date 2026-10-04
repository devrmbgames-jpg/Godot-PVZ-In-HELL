# NPC performance owner QA

The implementation has measured headless CPU improvements. Rendered FPS, GPU cost and subjective stutter remain unmeasured. Level geometry and navigation settings are preserved.

Current build: [Windows QA executable](../.export/windows/20261004-015623Z-e9e7dbec-npc-performance/PVZInHell.exe). Menu and main level each passed 120 headless startup frames. Relevant regression: 234 tests / 1491 assertions; connected seven-day district smoke PASS.

## Reproduction

Launch the latest Windows QA build through [.export/LATEST.cmd](../.export/LATEST.cmd), or run the project in Godot. Start a fresh QA session so an old save does not change the comparison. Use the same graphics settings, viewport resolution and debug/profiler mode as the supplied capture.

## Acceptance

- [ ] Observe the first morning, start and end a shift, and check the phase transitions for periodic NPC planning stalls.
- [ ] Capture profiler data while light-sensitive NPCs travel; compare NpcRouteService.plan, NpcLightingService.exposure_at, DistrictPopulationService.current/position_for and LightCircuitService.state_for/entity_for with the original screenshot.
- [ ] Confirm several simultaneous route requests produce movement over adjacent frames, without prolonged waiting or invalid direct crossings of hazards.
- [ ] Switch and flicker lights near a light-sensitive NPC; confirm behavior follows visible light promptly.
- [ ] Hide in darkness and behind physical cover; confirm perception still loses/reacquires the player correctly.
- [ ] Verify ordinary service and an evening delivery after a phase change.
- [ ] Record actual frame-time median, p95 and maximum in the rendered build; investigate any remaining dominant cost from that new evidence.

CPU benchmark can be repeated with `Godot --headless --path . res://utils/benchmark_npc_planning.tscn`. This measures route and light-query batches plus scheduled level systems; it does not measure rendering or native body integration.
