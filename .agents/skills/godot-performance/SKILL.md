---
name: godot-performance
description: >
  Use for profiling and performance work in this Godot 4.7 project: CPU/GPU
  bottlenecks, draw calls, script/GECS cost, physics/Jolt cost, allocations,
  instancing, materials, measurable optimization, memory leaks, lifetime,
  and Godot 4.7.1 shutdown-only retention diagnostics.
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
- Shutdown ObjectDB/Resource/RID retention alone does not prove a memory leak. One-time allocations,
  bounded services/caches, pooling and warmed memory reuse are acceptable. Preserve diagnostics.
- **Owner decision / known engine limitation (Godot 4.7.1):** retention warnings about
  `GDScript`, `GDScriptNativeClass`, `Resource`, `StringName` and RID **exclusively during
  editor/process shutdown** are `KNOWN_ENGINE_LIMITATION / DEFERRED`. They do not block
  a task or justify independent leak investigation. Preserve raw evidence in logs; do
  not silence parser/runtime warnings globally, or manipulate typing, references,
  `WeakRef`, `free()` or GECS to suppress shutdown warnings. Re-evaluate this exact
  category **only after adoption of stable Godot 4.8+** and relevant upstream-fix
  review. No move to Godot 4.7.2 is currently planned; a different engine/build
  must not silently cancel this decision.
- A warning *only* from the deferred category does not require a new growth test
  by itself. Runtime memory growth, Node leaks, invalid lifetime/destruction,
  use-after-free or double-free are still real defects to investigate.
- Prove defects through sustained post-warmup growth, survivors after their owned lifecycle,
  unbounded containers/references, use-after-free, double-free or ownership violations.
- Warm up, repeat equivalent operations 50–100 times per process, settle queued deletion/deferred
  work, then sample RSS/Private Bytes and available Performance static-memory/object/resource/
  node/orphan monitors. Compare full and tail trends under identical baseline/current conditions.
  Keep instrumentation bounded and distinguish allocator high-water marks from live survivors.
- Audit free/queue_free by actual type/owner; do not remove them or WeakRef mechanically.
  WeakRef does not own its target, but weak-reference containers can themselves grow.
  The rules in this "Allocation / lifetime" section are the canonical memory
  acceptance policy; other skills must link here instead of copying the policy.

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
