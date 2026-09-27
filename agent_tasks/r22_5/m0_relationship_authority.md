# R22.5 M0 — Relationship Authority

## Purpose

Normalize live Entity-to-Entity ownership/session/binding so Relationships are the sole authority. Ordinary Components may keep intrinsic/transient state or explicitly documented derived caches.

## Implemented migrations

### Cart cargo

Authority is `cargo -> cart` through `R_CartCargo`.

Relationship payload owns reversible binding lifecycle such as local pose, previous custom-integrator/sleep state and collision-exception bookkeeping.

`C_CartTransport.cargo` may exist only as a derived/rebuildable reverse cache. It must never win over the Relationship.

### Cart driver

Authority is `cart -> actor` through `R_CartDrivenBy`.

The Relationship owns session/capture lifetime state. `C_CartTransport` contains cart configuration/runtime motion, not driver authority.

`C_CartDriver.cart` currently exists only as a derived/rebuildable actor-side lookup cache.

### Deliberate throw

`C_ThrowDamage` contains authored configuration only:
- `throw_damage`;
- `window_seconds`.

Active attribution is `source -> instigator` through `R_ThrownBy`, whose payload owns `remaining_seconds` and `armed_tick`.

### Marker

Marker holder authority is `R_HeldBy`. `C_Marker.actor` is removed.

`C_Marker.parcel` remains transient current-stroke continuity, not ownership.

## Non-candidates

Do not mechanically turn every Entity/Object reference into a Relationship.

Known ordinary/derived state:
- `C_Interactor.target`: transient targeting;
- `C_PhysicsBodyRef.body`: proxy -> Godot object reference;
- `C_GrabControl.held_*`: reverse indexes for `R_HeldBy`;
- `C_PushControl.pushed_object`: reverse index for `R_PushedBy`;
- `C_Hazard.origin/instigator`: attribution/cache; follow ownership is `R_HazardFollow`;
- `C_Marker.parcel`: transient stroke state.

## Audit guard

When relationship work resumes, inspect remaining project-owned Component fields typed as `Entity`, `Array[Entity]`, or equivalent and classify each as:
1. intrinsic/transient;
2. derived/rebuildable cache;
3. authoritative cross-Entity relation.

Category 3 must become an `R_*` Relationship unless a concrete incompatibility with pinned GECS is documented.

## Validation

For relationship-only milestones:
- `python utils/validate_project_structure.py`;
- changed-file formatter/lint/static checks;
- search for removed legacy authority fields/classes;
- `git diff --check`;
- no runtime suite until final R22.5 validation unless blocked.
