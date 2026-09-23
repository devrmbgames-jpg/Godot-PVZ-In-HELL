# Architecture Refactor — Atomic Systems

Status: planned
Scope: project-wide System decoupling, starting with Cart Transport.
Do not start automatically while another roadmap task is active. Current R08 checkpoint remains authoritative until the user explicitly switches back to this refactor.

## Goal

Make every project `System` an atomic ECS processor:

- no direct `S_Foo -> S_Bar` calls;
- required hot-path data comes from GECS query/iterate components;
- different component sets/responsibilities are separate Systems;
- ordering uses `deps()`;
- cross-system communication uses Components, Relationships, typed Requests/Events/Results, Observers and CommandBuffer;
- reusable pure algorithms live in non-System helpers/services, not another System.

Godot RigidBody `_integrate_forces(state)` is the narrow exception at the Entity callback boundary. An Entity may forward that callback to independent physics solvers because `PhysicsDirectBodyState3D` cannot be produced by a normal ECS query. The solvers themselves remain independent and never call each other.

## Why this task exists

The current Cart Transport implementation mixes:
- session acquisition/release;
- input/focus interpretation;
- CharacterBody movement;
- driver following;
- cargo lifecycle/update;
- generic availability/grab checks.

It also contains repeated `get_component()` calls where the behavior should instead be split around explicit query component sets.

Current examples to remove:
- `S_CartTransport -> S_Grab`;
- `S_CartTransport -> S_CartCargo`;
- `S_Motion -> S_CartTransport`;
- `S_Motion -> S_Push`;
- `S_PlayerInput -> S_CartTransport/S_Push`.

Other project Systems must be audited after Transport; do not assume Transport is the only violation.

## Target Transport architecture

### 1. Session/ownership state

Use one authoritative transport binding, not mirrored mutable caches on both actor and cart.

Choose the exact Component/Relationship representation after checking pinned GECS relation/query support.

The binding owns only session facts:
- actor;
- cart;
- control-capture token / lifecycle state if still required.

Do not store movement solver state, cargo lists, input interpretation and ownership in one Component.

### 2. Input System

A narrow input System queries the actor-side component set it actually needs, for example:

```text
C_Controller
+ transport-driver/binding state
```

It derives transport intent only.

It does not:
- move the cart;
- call Cart movement System;
- call Grab/Push Systems;
- fetch unrelated Components in the hot loop.

If intent must cross from actor to cart, use authoritative relation/state or a small typed intent/state Component. Do not call another System to pull the value.

### 3. Cart Drive System

Cart movement is a separate System over the cart-side data it owns, for example:

```text
C_CartTransportConfig
+ C_CartDriveState / required transport state
```

Its query must supply required Components via `iterate()`.

It owns only:
- acceleration/braking;
- steering;
- CharacterBody movement;
- actual cart velocity;
- deterministic terrain collision rules that are part of transport mechanics.

It does not:
- query Grab through `S_Grab`;
- update Cargo by calling `S_CartCargo`;
- drive the Player RigidBody;
- route interaction input.

### 4. Driver Follow physics solver

Player RigidBody following the cart stays outside `S_Motion`.

At `E_RigidBodyCharacter._integrate_forces(state)`, the Entity may forward to the independent driver-follow solver as the allowed physics boundary exception.

Target shape:

```text
E_RigidBodyCharacter._integrate_forces(state)
    -> independent Impact solver
    -> independent CartDriver physics solver
    -> independent Push physics solver
    -> independent Motion solver
    -> independent Look/Crouch physics solvers
```

Exact ordering must be explicit and based on owned state/components, not on one System calling another.

`S_Motion` must know nothing about Cart Transport or Push.

### 5. Cargo System

Cargo is a separate query/lifecycle.

It consumes:
- cargo binding/support state;
- cart motion state needed for assistance;
- cargo physics state at its allowed physics callback boundary.

It must not be manually called by Cart Transport after each cart step.

Cart movement publishes/updates its own state; Cargo observes/queries that state independently.

### 6. Interaction/session transitions

Interaction actions must request/commit transport session state without turning a System into a service API.

Prefer:
- typed request/event;
- relation/component transition;
- Observer for rare add/remove lifecycle;
- a non-System domain service only when the operation is truly imperative/pure and cannot be modeled as ECS state.

Do not keep public static `begin/end/current/can_begin` on a System merely because other code needs a callable API.

## get_component policy

Inside a System `process()` hot path:

- if every matched Entity requires a Component, put it in `with_all(...).iterate(...)`;
- if only some Entities need another behavior/component set, split that behavior into another System/query;
- do not use repeated `get_component()` as an ad-hoc optional-component dispatch mechanism.

Allowed boundary cases:
- rare one-shot lifecycle callback/Observer where an Entity arrives outside a matching iteration;
- physics Entity callback exception;
- explicit cross-Entity lookup that cannot be expressed by the pinned GECS query/relation API, documented locally.

Even boundary lookups must not become a hidden System-to-System dependency.

## Project-wide audit after Transport

Audit all files under `content/systems/` for:
- `S_OtherSystem.some_method()`;
- repeated `get_component()`/ `has_component()` in `process()`;
- Systems acting as static service libraries;
- monolithic Systems with unrelated optional component branches.

For each finding:
1. determine authoritative data;
2. express required component set in query;
3. split responsibility when component sets differ;
4. replace System call with state/event/relation/dependency;
5. preserve behavior without opportunistic gameplay redesign.

Do not refactor unrelated pure services simply because they have static methods; this task targets ECS System boundaries.

## Validation

During implementation:
- static structure validation;
- formatter/static checks;
- `git diff --check`;
- no visual run;
- no repeated runtime/GUT loops.

Runtime validation follows the repository task budget and user-owned runtime rule.

## Completion criteria

- Transport Systems contain no calls to another `S_*` class.
- `S_Motion` contains no Cart/Push dispatch.
- Transport hot loops receive required components from queries instead of repeated `get_component()`.
- Cart drive, driver follow, cargo and session lifecycle have separate ownership/responsibility.
- Physics exception exists only at Entity callback boundaries.
- Project-wide System audit is documented and remaining violations are either fixed or explicitly queued.
