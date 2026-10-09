---
name: godot-physics-4.7
description: Use for Godot 4.7/Jolt body movement, collisions, contacts, joints, queries and physics-authority bugs.
---

# Godot 4.7 / Jolt Physics

Project baseline: Godot 4.7, Jolt Physics, Forward Plus.

This skill is a focused reference, not a replacement for project architecture. The checked-out project and Godot 4.7 runtime are authoritative; use Godot AI MCP ClassDB/diagnostics when an API detail is uncertain.

## Project authority

- Godot/Jolt owns physical transform and velocity of physics bodies unless an explicit synchronization contract says otherwise.
- GECS Components/Relationships own gameplay/domain state, not a duplicate physics simulation.
- Scheduled Systems do not become imperative physics services. Reusable physics behavior belongs in the existing Entity callback/service/solver boundary.
- Do not add a second transform/velocity authority merely to make a system easier to query.

## Body choice

- `StaticBody3D`: non-simulated collision geometry.
- `RigidBody3D`: solver-owned dynamic body; prefer forces, impulses, velocity, or controlled state changes instead of per-frame transform writes.
- `CharacterBody3D`: script-controlled movement via `move_and_slide()` / `move_and_collide()`.
- `Area3D`: overlap/detection/field behavior, not solid collision.

Collision layer = what the object is on. Collision mask = what it queries/reacts to. Keep authored layer/mask contracts stable unless migration is explicit.

## RigidBody3D rules

- Avoid fighting the solver by assigning transform every physics tick.
- Apply impulses for instantaneous changes and forces for continuous acceleration.
- For controlled teleports/state replacement, use a solver-safe path such as `_integrate_forces(state)` or an existing project helper rather than mixing direct writes with normal simulation.
- Clear or preserve linear/angular velocity deliberately when teleporting.
- Enable CCD only for bodies whose speed/thickness actually requires it; it has a cost.
- Let sleeping work unless gameplay requires permanent activity.

## Tuning and stability

- Keep simulation work in the physics step; do not apply forces/movement from render-frame callbacks.
- Prefer Godot's built-in physics interpolation before inventing a parallel visual-transform simulation.
- Treat mass as relative collision weight, not fall speed; use gravity scale/damping/material friction/restitution for feel.
- For tunneling, first reason about speed, collider thickness and physics tick distance; then use CCD, thicker collision, a speed cap, or a higher physics rate as justified by the mechanic.
- Extreme mass ratios, unnecessary awake bodies, and unstable joints can create jitter and solver cost. Tune them before replacing the solver.
- Do not globally raise physics tick rate or solver cost to fix one local interaction without measuring the project-wide effect.
- After teleports/discontinuities, reset interpolation/history where needed so visuals do not smear or snap from stale state.

## Queries

Use the cheapest representation that fits the lifecycle:

- `RayCast3D` / `ShapeCast3D`: persistent scene-authored query updated with physics.
- `PhysicsDirectSpaceState3D`: immediate one-shot or batched code query.
- Exclude self RIDs explicitly when direct queries can hit the querying body.
- Reuse stable query parameters/buffers in hot paths instead of rebuilding broad data structures every tick.

Do not assume a direct-space query is inherently superior to a RayCast node; choose based on ownership, update cadence, and measured cost.

## Jolt-specific traps

For version-sensitive behavior, verify against Godot 4.7/Jolt docs or the running editor.

Known areas that differ from GodotPhysics3D and deserve explicit checking:
- ray-query face-index support/settings;
- one-body joint/world-node semantics;
- unsupported or ignored soft-limit properties on some joints;
- kinematic/frozen contact-generation settings;
- collision-margin behavior and small-shape normals;
- contact/reporting differences around kinematic bodies.

Do not cargo-cult old GodotPhysics3D workarounds into Jolt.

## Validation

For physics code changes:
1. validate changed GDScript through Godot parser/diagnostics;
2. use the narrowest existing GUT test or headless smoke surface if behavior must be proven;
3. use live MCP scene/runtime inspection only when it materially helps;
4. leave subjective movement/feel validation to the user unless explicitly asked to run gameplay.

Source inspiration: adapted selectively from `gamedev-skills/awesome-gamedev-agent-skills` Godot physics guidance (Apache-2.0); project rules override generic guidance.
