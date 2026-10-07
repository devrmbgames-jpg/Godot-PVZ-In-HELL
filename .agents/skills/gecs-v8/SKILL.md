---
name: gecs-v8
description: >
  Use only for GECS v8-specific Components, Entities, Systems, Observers, queries,
  relationships, command buffers, scheduling, or version-sensitive GECS API work.
---

# GECS v8

Pinned local source under `addons/gecs/` is the API authority. Inspect it only when the GECS API is uncertain; never patch/format/upgrade it during ordinary project work.

## Core model

- Components are data/state only.
- Scene-authored reusable Components should normally be exposed through `component_resources`.
- Entities own identity/lifecycle and thin Godot scene/physics glue.
- Systems own scheduled behavior; Observers own discrete/reactive transitions.
- Reusable algorithms that are not ECS scheduling belong in non-System services/solvers/helpers.
- Presentation must not become gameplay authority.
- Godot UI (`Control`, HUD, menus) remains ordinary glue outside ECS scheduling; do not create UI-only Components/Systems.
- Entity Templates / `ET_*` Traits are authoring/compiler recipes only. Runtime behavior is driven by the Components/Relationships they materialize, not by Trait ticks.

## Systems and queries

- A project `System` must not call another `System` as a service/helper.
- Use `deps()`/groups for ordering and Components, Relationships, typed requests/events/results for data flow.
- Reserve `S_*` / `extends System` for real scheduled work.
- Required hot-path Components belong in `with_all(...).iterate(...)`; avoid repeated `get_component()` inside homogeneous process loops.
- Split broad optional-component behavior into narrow Systems/sub-systems where practical.
- Use CommandBuffer for structural mutations during iteration unless pinned GECS explicitly guarantees the direct operation is safe.

## Relationships

Authoritative cross-Entity ownership/link state uses `r_*.gd` filenames and `R_*` classes, even when GECS requires the Component base. During Refactoring v2 legacy files may still live under `content/relationships/<subsystem>/`; the target location is `content/domains/<domain>/relationships/` or `content/shared/relationships/`. Derived lookup/cache state that is not authority remains `C_*`.

## Entity lifetime contract

GECS queries and synchronous gameplay handlers should provide a strong lifetime contract.

- An Entity yielded by the owning synchronous query/handler is treated as valid for that synchronous operation.
- Required Components supplied by a query are invariants; downstream code should not repeatedly re-fetch and null-check them.
- Do not add `is_instance_valid()` to ordinary System/Service code merely because an Entity is a Godot Object.
- Revalidate only after a real time/lifetime boundary: deferred/queued dispatch, stored references, delayed callbacks, queued events/requests, teardown, or another explicitly asynchronous path.
- If a required Entity/Component unexpectedly disappears in synchronous code, use a debug `assert(...)` when useful to expose the violation and fix lifecycle ownership rather than silently returning.
- Structural removal/destruction must not deliberately invalidate references mid-transaction; use the GECS-safe lifecycle/CommandBuffer path where required.

Relationships need the same explicit contract: either the relationship target is guaranteed live while the relationship exists, or the single resolving/lifecycle boundary handles stale targets. Do not make every consumer independently defend against stale relationship targets.

## Godot physics boundary

`PhysicsDirectBodyState3D` exists only in the body's physics callback. An Entity may therefore forward its callback to multiple independent non-System physics solvers.

Those solvers:
- do not call each other or other Systems;
- read only their owned state/relationships;
- mutate only their own physics contribution;
- should not be registered as no-op Systems merely to provide static helper methods.

## Service and execution boundary

A Service must not become a hidden System. Generic per-frame `tick/update/process` ownership, broad scheduled ECS iteration, cooldown/time progression, or orchestration of several domains belongs in Systems/Observers unless an engine callback contract requires a Solver.

A thin `S_*` whose only meaningful job is forwarding every frame to `SomeService.tick()` is an architecture smell, not a preferred abstraction.

## State transitions

For input-driven mechanics:
- input/controller data = requested intent;
- Component/Relationship = authoritative state;
- owning System/Observer = validation and transition;
- presentation consumes authoritative state.

When a GECS behavior is uncertain, inspect the smallest matching local source/doc and existing project usage before expanding further.
