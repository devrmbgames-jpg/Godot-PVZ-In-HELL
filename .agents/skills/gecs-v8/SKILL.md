---
name: gecs-v8
description: >
  Design and modify GECS v8 Components, Entities, Systems, Observers, queries, relationships,
  command buffers, sub-systems, system groups, and ordering.
---

# GECS v8

The project's pinned GECS v8 source is the API authority.

Upstream best-practice baseline:
`csprance/gecs:addons/gecs/docs/BEST_PRACTICES.md`, main snapshot
`69c7a2b9ad75f1a12a35c57895d6a751081055c0`.

Project-specific architecture rules may be stricter than upstream examples. In particular, this project forbids direct System-to-System service calls.

## Inspect first

When an API is uncertain:
1. inspect pinned local GECS source/docs when available;
2. inspect existing project usage;
3. consult matching-version upstream only when needed.

Never patch/format/upgrade `addons/gecs` during ordinary project work.

## Components

Follow the upstream GECS component rules:

- Components are **pure data/state**. No gameplay behavior belongs in a Component.
- Prefer composition of small Components over Entity inheritance hierarchies.
- Author tunable gameplay data with typed/exported fields.
- A concept belongs in a Component when Systems need to query its presence, it can appear/disappear/change at runtime, and it is serializable data.
- Do not create Components merely to wrap Node references.

Project rule: scene-authored reusable Components should normally be visible/configurable through `component_resources`.

## Entity glue

An Entity subclass bridges Godot's SceneTree and ECS.

Keep data on the Entity itself when all of these are true:
- it is a reference to the Entity's own child Node;
- it is scene glue, not gameplay state;
- it is not added/removed dynamically;
- Systems never need to query by its presence;
- it is unsuitable for Resource serialization.

Cache own-child Node handles once with typed `@onready` fields. Do not repeatedly walk the SceneTree in hot Systems.

When a query is homogeneous, cast an Entity to its concrete Entity class once and reuse that variable for Entity API + scene-root/glue access. Avoid repeated/double casts of the same object.

## Systems: single responsibility

Each System/sub-system handles one concern.

A large feature may use several atomic Systems or GECS `sub_systems()`. Use `sub_systems()` when one feature owns several distinct query/process pairs but they still form one cohesive system boundary.

Do not create one universal System with many optional-component branches.

### Atomic System rule

Systems do not call other Systems as service/helper APIs.

Do not write:

```gdscript
S_OtherSystem.some_method(...)
```

from another System.

Use instead:
- `deps()` or SystemGroup ordering for execution order;
- Components/Relationships for persistent state;
- typed Requests/Events/Results for commands/results;
- Observers for rare reactive transitions;
- CommandBuffer for safe structural mutations;
- a non-System service/helper for reusable pure/imperative algorithms that are not ECS processing.

Static methods on a System class are not a general service layer.

### System identity and registration

Reserve `extends System` and the `S_*` naming convention for classes that genuinely participate in GECS scheduling through a real `query()/process()`, `sub_systems()`, or an explicit `process_empty` inbox/event processor.

A class is **not** a System merely because gameplay code calls it:
- static-only RigidBody/physics callback algorithms belong in a non-System solver/helper;
- pure calculations and imperative domain lookups belong in a non-System helper/service;
- do not keep empty or no-op System nodes in SystemGroups;
- do not scan `ECS.world.systems` to locate a System instance as a service locator; route commands through typed requests/events/state or explicit non-System wiring;
- when converting a legacy pseudo-System, remove its stale SystemGroup node and keep scheduling dependencies only for work that is still actually scheduled by GECS.

This keeps SystemGroups, `deps()`, profiling, and query contracts truthful instead of using `System` as a namespace for static functions.

### Gameplay and presentation boundary

Gameplay/physics authority writes authoritative state. Pure presentation should consume that state separately when it can do so without changing gameplay semantics.

Examples of presentation that should normally be separated:
- camera-only interpolation;
- mesh highlight/overlay changes;
- VFX/SFX-only reactions;
- HUD state.

Gameplay-critical child Nodes such as collision shapes, interaction raycasts, hold anchors, and other scene glue may still be accessed by the owning System/solver through the Entity. Do not split them merely because they are Nodes.

### Query is the System data contract

Required hot-path Components belong in the query and should be returned via `iterate()`.

Prefer:

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_A, C_B, C_C]).iterate([C_A, C_B, C_C])
```

over matching one Component and repeatedly calling `get_component()` for the others in `process()`.

If two behaviors need different Component sets, split them into different Systems/sub-systems instead of optional lookup branches.

Boundary `get_component()` remains acceptable for:
- rare Observer/lifecycle callbacks receiving an Entity outside query iteration;
- an explicit cross-Entity lookup that cannot reasonably be expressed with pinned GECS query/relationship APIs;
- the Godot physics callback exception below.

Document non-obvious boundary lookups.

### Queries

Follow upstream performance guidance:

- prefer specific `with_all` / `with_none` / `with_any` queries;
- prefer component queries over SceneTree group queries;
- use `.enabled()` where enabled-state filtering is the actual contract;
- use `iterate([...])` for repeated component access;
- early-continue/return when no work is needed;
- do not query broadly and filter manually when GECS can express the filter.

## Structural changes

During System/Observer iteration, use `cmd` / CommandBuffer for structural changes such as:
- add/remove Component;
- add/remove Entity;
- relationship mutations when immediate cache invalidation would invalidate iteration.

Respect the configured flush mode.

Do not directly mutate World structure during forward iteration unless pinned GECS explicitly guarantees that operation is safe.

## Observers

Use Observer for discrete/reactive transitions:
- component/relationship added/removed;
- query match/unmatch;
- typed event;
- rare lifecycle side effects.

Do not use Observers as per-frame state machines.

Property changes are not magically observable; use project/pinned GECS change notification only when a real Observer requires it. Do not emit change events for hot motion/look values every frame.

Use `cmd` when Observer reactions cause structural changes or recursive cascades.

## Relationships

Use Relationships for authoritative cross-Entity ownership/state when the relation itself matters.

When the project accumulates repeated relationship construction/patterns, prefer a centralized typed relationship factory/helper instead of duplicating `Relationship.new(...)` shapes everywhere.

Derived caches may accelerate lookup but never become a second ownership authority.

## System groups and ordering

Use scene-based SystemGroups for coarse phases such as input/gameplay/physics/UI/cleanup. The project already organizes main systems into groups; preserve and improve that structure rather than replacing it with manual cross-System calls.

Use:
- SystemGroups for coarse processing phases;
- `deps()` for specific ordering constraints inside/among compatible phases.

Do not encode ordering by calling another System directly.

## Pending-delete lifecycle

When zero Health/destruction needs debris, animation, VFX/SFX, loot, corpse persistence, or delayed cleanup:

1. commit the gameplay state transition;
2. add a pending-delete/cleanup state when deletion is actually requested;
3. let a dedicated late cleanup System remove Entities.

Do not combine "became dead/destroyed" with immediate entity removal.

This project may use a typed equivalent of upstream `C_IsPendingDelete`; preserve the semantic separation even if the exact class name differs.

## Physics callback exception

Godot RigidBody integration is the narrow project exception.

`PhysicsDirectBodyState3D` exists only inside the body's physics callback, so an Entity may forward `_integrate_forces(state)` to multiple **independent physics solvers**.

Example boundary:

```text
E_RigidBodyCharacter._integrate_forces(state)
    -> ImpactCaptureSolver
    -> PushActorSolver
    -> CartDriverSolver
    -> CharacterMotionSolver
    -> CharacterLookSolver
    -> CrouchSolver
```

Rules still apply:
- one solver does not call another solver/System;
- orchestration exists only at the Entity callback boundary;
- each solver reads only its owned data/relationships and mutates only its own physics contribution;
- a class used only as a physics solver should not masquerade as a registered ECS System; prefer a clearly named non-System solver/helper unless it also has real ECS query processing.

## State transitions

For input-driven mechanics:
- Controller/Input Component = requested intent;
- mechanic Component/Relationship = actual authoritative state;
- owning System = validation/state transition;
- presentation consumes actual state.

Do not add relay Components that merely copy data without defining meaningful state/ownership.

## Prefabs

Prefer Godot scenes as Entity prefabs.

Use Inspector-authored component configuration for stable design data when practical. Programmatic Components are appropriate for genuinely runtime/dynamic state.

Keep spawning/registration lifecycle explicit and avoid making UI/presentation the authority for Entity creation state.

## Reference quality bar

A well-shaped project System should resemble `S_Jump`:
- focused responsibility;
- explicit component query;
- `iterate()` for required data;
- no direct System calls;
- no static service surface;
- no unrelated presentation/lifecycle concerns.

A System that needs many public static APIs, many unrelated regions, repeated `get_component()`, or several foreign System calls is a refactor candidate.
