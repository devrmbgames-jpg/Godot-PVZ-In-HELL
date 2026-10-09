---
name: godot-performance
description: Use for measured Godot profiling/optimization of CPU, GPU, GECS, physics, rendering or allocations.
---

# Godot Performance

Performance work is evidence-driven: reproduce -> measure -> identify bottleneck -> change one cause -> measure again.

Do not use this skill as permission for speculative refactors.

## First establish the budget

Translate the target FPS to frame time:
- 120 FPS: 8.33 ms
- 60 FPS: 16.67 ms
- 30 FPS: 33.33 ms

Measure on representative hardware/build whenever the result matters. Editor/debug measurements are useful for diagnosis but are not shipping numbers.

## Triage

Classify the dominant cost before changing architecture:

- CPU/script: GDScript/GECS queries, algorithms, scene-tree traversal, allocations, event volume.
- Physics: active bodies, complex collision shapes, contact count, broadphase churn, unnecessary queries, disabled sleeping.
- Rendering CPU: node/material/state submission, excessive unique surfaces/materials.
- GPU: draw calls, overdraw, expensive shaders, realtime shadows/lights, resolution/fill rate.
- Loading/memory: synchronous resource loads, asset size, churn, duplicate resources.

Optimize the dominant side first.

## Project-specific priorities

### GECS / script
- Do not replace a correct GECS ownership model merely to shave hypothetical overhead.
- Profile query/system frequency and entity counts before changing scheduling.
- Cache stable references/results where lifecycle permits.
- Avoid broad tree scans or container construction every frame.
- Run work less often when gameplay semantics allow; algorithmic reduction beats micro-optimization.

### Physics / Jolt
- Keep body authority in Jolt.
- Prefer simple collision primitives where they are sufficient.
- Let sleeping remove inactive bodies from active simulation.
- Avoid unnecessary continuous collision detection, contact reporting, or per-frame shape/ray queries.
- Measure before moving gameplay into lower-level PhysicsServer/RID code.

### Rendering
- Share materials/textures where possible.
- Use MultiMesh/instancing for genuinely repeated static or simple geometry when scene ownership permits.
- Reduce unique materials/surfaces and unnecessary transparent overlap.
- Bake/static-light where appropriate to the visual target.
- Avoid material duplication for per-instance cosmetic parameters when instance shader parameters are sufficient.
- Measure draw calls and GPU frame time before/after.

### Allocation / lifetime
- Avoid new large Arrays/Dictionaries/resources every frame.
- Pool only objects that are actually high-frequency/hot-path; do not add lifecycle complexity to rarely spawned objects.
- Prefer reuse/caching where ownership and invalidation are clear.
- Distinguish actual live object/lifetime growth from bounded caches and allocator high-water marks.
- For leak claims and shutdown-only Godot 4.7.1 warnings, use the focused
  [memory/lifetime procedure](../validation-workflow/references/memory-lifetime.md)
  rather than speculatively changing `WeakRef`, `free()` or GECS ownership.

## Evidence and reporting

For an optimization task, report:
- reproduction/scene;
- target budget;
- measured bottleneck;
- changed cause;
- before/after metric when measurement was available;
- what remains unmeasured.

Never report "optimized" or "faster" solely from code inspection.

## Tool use

- Godot Profiler/Monitors are preferred runtime evidence.
- Godot AI MCP can inspect editor/runtime diagnostics/state when useful, but do not dump whole SceneTrees/logs by default.
- Use existing project smoke/GUT surfaces only when they can falsify the optimization's behavior.
- Do not launch gameplay repeatedly after small edits.

Source inspiration: adapted selectively from `gamedev-skills/awesome-gamedev-agent-skills` performance guidance (Apache-2.0); project rules override generic guidance.
