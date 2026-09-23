---
name: project-rules
description: >
  Repository-specific architecture, dependency, physics-authority and validation
  rules for code changes in this Godot project.
---

# Project rules

Use this skill for project code/architecture changes. Navigation/token rules come from root `AGENTS.md`; do not reread project-wide docs unless the task needs them.

## Dependency boundary

Everything under `addons/` is read-only by default. Inspect pinned APIs when needed, but never patch, format, rename, upgrade, or commit addon changes unless explicitly requested.

## Architecture defaults

- Godot physical bodies own physical transform/velocity unless a documented sync contract says otherwise.
- Immutable design data -> `Resource`.
- Mutable runtime actor state -> `Component`.
- Independent identity/lifecycle -> `Entity`.
- Components are data-only.
- Behavior belongs in Systems/Observers/services.
- Entity scripts may contain scene glue, own-child Node references, engine callbacks, and thin forwarding.
- Avoid reusable Component Resources holding direct scene-child Node references.
- Prefer typed Request/Event/Result classes over semantic Dictionaries.
- Reuse an existing service/System/Observer contract before creating a parallel manager.
- Presentation is never gameplay authority.
- Scene-authored serializable Components should prefer `component_resources` so they are visible in Inspector; runtime-only construction must have a real serialization/lifecycle reason.

## Atomic System rule

Project Systems are atomic ECS processors.

- A `System` must not call another `System` as a service or helper.
- Never write `S_Foo.some_method()` from inside another `S_Bar`.
- System ordering is expressed with `deps()`; data flow is expressed through Components, Relationships, typed Requests/Events/Results, Observers, and CommandBuffer mutations.
- If behavior requires a reusable pure algorithm, move that algorithm to a non-System service/helper or typed data object instead of calling another System.
- If a System needs component data for every matched Entity, declare those Components in `query().with_all(...).iterate(...)` and consume the provided component arrays. Do not repeatedly call `get_component()` inside the hot process loop when the query can supply the component.
- Split a broad System into several small Systems when different behaviors require different component sets. Prefer multiple narrow archetype queries over one monolithic System with optional `get_component()` branches.
- Components remain data-only; splitting Systems must not move behavior into Components.
- Cross-Entity ownership/state must use authoritative Relationships/Components rather than caches queried through another System.
- Static methods on System classes are not a general service layer. Imperative gameplay commands should become typed request/event/state transitions consumed by the owning System/Observer where practical.

### Physics exception

Godot physics integration is the only intentional exception.

A physics-body Entity may forward Godot callbacks such as `_integrate_forces(state)` to dedicated solver functions because `PhysicsDirectBodyState3D` exists only in that callback. A single Entity callback may invoke multiple independent physics solvers.

Even in this exception:
- one physics solver must not call another System;
- `S_Motion` must not dispatch to `S_Push`, `S_CartTransport`, cargo, combat, etc.;
- each solver reads only its own required Components/Relationships and mutates only its owned state/physics contribution;
- orchestration happens at the Entity callback boundary, not System-to-System.

## GDScript

Load `.agents/skills/gdscript-style/SKILL.md` for `.gd` edits.

Required baseline: static typing, no shadowing, no magic gameplay constants, explicit casts from Variant/untyped collections, allocation-aware hot paths, project naming conventions, underscore-based private API, `_on_` signal callbacks, and `##` documentation for script responsibility/public API.

## Change discipline

Make the smallest coherent change. After finding the owner/contract, do not opportunistically refactor unrelated code.

For already-designed repetitive edits, prefer the `mechanical_worker` subagent. Architectural decisions stay with the main agent.

## Validation

Use the narrowest relevant project checks. Never report a runtime/formatter/test result that was not actually executed.

Validation cadence is intentionally batched:
- ordinary milestone/subtask commits use deterministic structure/path checks, formatter/static checks, targeted inspection, and `git diff --check`;
- do **not** run GUT, headless smoke, or broad runtime suites after every milestone;
- run the relevant GUT + headless smoke/runtime regression surface once near the end of the complete `Rxx` / `Rxx.x` task before marking it complete;
- early targeted runtime/test execution is allowed only on explicit user request or for a concrete blocking bug that cannot be validated statically.
- per complete `Rxx` / `Rxx.x` task, default to at most one GUT invocation and one headless smoke/runtime invocation total; an early blocking invocation consumes that budget;
- additional runtime reruns require explicit user approval;
- automated physics scenarios must verify a critical deterministic contract, not gameplay feel/tuning that the user checks manually;
- do not create/expand ramp, step, uneven-terrain, vehicle-feel, camera-feel, or animation-feel smoke coverage unless the user explicitly requests it;
- never send full runtime logs back into context; filter to the smallest relevant failure/PASS evidence.

Rendered/visual Godot validation is **opt-in only**:
- do not launch a rendered game/editor for validation;
- do not capture screenshots or screen recordings;
- do not inspect rendered frames through an agent;
- do not treat a visual task as implicit permission.

Only perform any of the above after explicit user approval in the current task/conversation. Headless Godot/tests/static validation are still allowed. If visual confirmation remains necessary, report it as `NOT RUN — user visual validation required`; the user performs visual tuning in the engine.
