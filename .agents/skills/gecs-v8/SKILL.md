---
name: gecs-v8
description: >
  Design and modify GECS v8 Components, Entities, Systems, Observers, queries, relationships,
  command buffers, and system ordering. Use whenever code extends Component, Entity, System,
  Observer, QueryBuilder, or touches GECS contracts.
---

# GECS v8

The project's checked-out/pinned GECS source is the API authority.

## Inspect first

When an API is uncertain:
1. inspect local GECS `ecs/` and `docs/`;
2. inspect existing project usage;
3. consult matching-version upstream only if needed.

**Do not modify, format, rename, patch, or upgrade GECS under `addons/` during normal project work.**
Inspect it only as read-only API/reference code unless the user explicitly requests dependency work.

## Data and behavior

- `Component`: lightweight data/state Resource.
- `Entity`: identity/lifecycle plus allowed Godot scene glue.
- `System`: repeated gameplay/update logic.
- `Observer`: reactive logic for rare component/relationship/query/event transitions.
- Node references to an entity's own children belong on the Entity subclass, not in Components.

## Fast systems

Use `iterate([...])` for hot systems:

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_Motion, C_Controller]).iterate([C_Motion, C_Controller])
```

Express ordering with `deps()` when correctness depends on another System.

Avoid repeated `get_component()` inside hot loops when `iterate()` can provide components.

## Atomic Systems

Systems do not call other Systems.

Use:
- `deps()` for execution ordering;
- query composition for required data;
- Components/Relationships for state;
- typed Requests/Events/Results + Observers for discrete transitions;
- CommandBuffer for structural changes during iteration.

Do not use another `S_*` class as a service API from inside a System.

A System query is its data contract. If the behavior requires `C_A + C_B + C_C`, prefer:

```gdscript
func query() -> QueryBuilder:
    return q.with_all([C_A, C_B, C_C]).iterate([C_A, C_B, C_C])
```

over matching `C_A` and repeatedly calling `get_component(C_B/C_C)` in `process()`.

When different behavior needs different component sets, split it into separate Systems rather than accumulating optional branches and lookups in one System.

Physics-body callbacks are the narrow exception: an Entity may forward `_integrate_forces()` to multiple independent solvers. Those solvers still must not call each other.

Use `CommandBuffer` for structural mutations during iteration unless the exact pinned implementation guarantees safety otherwise.

## Observers

Use Observer for discrete/reactive changes, not as a replacement for state machines or per-frame systems.

Typical v8 modifiers:
- `.on_added()`, `.on_removed()`
- `.on_changed([...])`
- `.on_match()`, `.on_unmatch()`
- `.on_event(...)`

Property changes are not automatic: a setter must emit `property_changed` for `on_changed` to fire.

Do not emit property-change events for motion/look/physics values every frame unless actually required.

Use `cmd` in Observer callbacks when reactions cause structural mutations or recursive cascades.

## State transitions

For crouch/jump/cast-like mechanics:
- controller/input field = requested intent;
- mechanic component = actual validated state;
- owning System = validation/state transition;
- animation/UI/presentation consumes actual state.

Avoid redundant relay Components that only copy intent.
