# R22.5 M1 — System Decomposition

Status: **DONE**
Owner task: [R22.5](../roadmap_22_5_gecs_architecture_polish.md)

## Task state

### Goal
Remove structural System coupling and pseudo-System/service patterns while preserving behavior.

### Current
Verified against current production after R22 `5feee8fb`. All historical decomposition targets are already implemented; retain current owners rather than repeat migrations. Current disposition is recorded below. Next: M2 targeting/marker/domain presentation audit.

### Validation
Static current-source audit: 39 scheduled System scripts each define query/process; no static System helpers, class calls, System-instance construction or System locator scans in production systems/services/entities/observers/definitions. Exact lifecycle/physics/input/receiving/day/damage owners inspected. Independent reread: no material M1 findings. Diff whitespace check PASS. No GUT/engine run for M1; final task runtime budget remains M4.

### Owner QA / blockers
No implementation blocker. Gameplay/visual QA remains in the owning feature tasks.

## Verified production disposition (2026-10-02)

| Area | Current owners and decision |
| --- | --- |
| Grab | `S_Grab` schedules input/validation through CommandBuffer; `O_GrabLifecycle` reacts to `R_HeldBy`; `GrabService` owns imperative transactions/anchor helpers; `GrabPhysicsSolver` performs spring math. Authored body callbacks retain physics authority; generic rigid bodies use the explicit pre-physics velocity/force fallback. No System service API. |
| Push | `S_Push` queues session validation; `O_PushLifecycle` reacts to `R_PushedBy`; `PushService` owns begin/end; `PushCartSolver`/`PushActorSolver` run from their respective body callbacks. |
| Cart | `O_CartLifecycle` and cargo/transport services own `R_CartCargo`/`R_CartDrivenBy`; `E_TransportCart` calls `CartDriveSolver`, actor/cargo callbacks call their separate solvers. No empty Cart pseudo-System is registered. Derived caches remain secondary. |
| Player input | `S_PlayerInput` captures raw input/edges; `S_PlayerIntent` derives modes from focus and relationship services. Escape capture checks drawing focus only to route/consume the OS event; it does not perform a drawing transition. No Push/Transport System lookup. |
| Receiving | `S_Receiving` owns Morning retry scheduling; `ReceivingDeliveryService` arms/advances typed `ReceivingBatch` transactions; `ReceivingPackageFactory` constructs/places packages. Domain identity/history paths reused. |
| Day | `S_DayPhase` processes `DayTransitionRequest` in `C_DayCycle`; consumers use `DayPhaseService` or state/signals. Night persistence consumer remains independently scheduled. |
| Damage/Impact | Health arithmetic is `O_Damage`; typed request/result events separate lifecycle/presentation. `ImpactCaptureSolver` captures physics snapshots; `S_Impact` consumes/coalesces inboxes; `R_ThrownBy` owns deliberate throw attribution/lifetime. No historical `S_Damage` service facade remains. |
| Empty/legacy | All 39 current System classes have scheduled query/process work. Static services/solvers are `RefCounted`, not registered Systems. No removal needed. |

---

## Goal

Remove structural coupling and pseudo-System/service patterns while preserving behavior. Verify every historical issue against current `master` before editing.

## Current disposition targets

| Area | Target |
| --- | --- |
| Damage / Impact | R08 already moved submission/capture toward typed paths; regression-audit only unless a violation reappeared. |
| Grab | Separate holder input, ownership lifecycle, physical solver, and imperative helpers. |
| Push | Relationship/session lifecycle separate from cart/actor physics solvers. |
| Cart transport/cargo | Relationship authority already normalized; finish truthful scheduled-vs-solver classification without mirrored authorities. |
| Player input | Raw capture stays focused; mode constraints derive from authoritative focus/state, not foreign Systems. |
| Receiving | Separate phase reaction/batch state from spawn-space/package construction. |
| Day phase | Keep transition System; consumers should not use it as a global service facade. |
| Empty/legacy Systems | Remove or reclassify after verifying no current feature owns them. |

## Grab

Keep `R_HeldBy` as sole ownership authority.

Desired boundaries:
- input/session decision;
- relationship lifecycle side effects;
- physical hold solver called from body callback;
- slot/anchor/query math in non-System services where appropriate;
- typed transitions instead of direct calls into foreign Systems.

Do not create a second ownership authority in reverse caches.

## Push

Keep `R_PushedBy` as authority.

Separate:
- begin/end validation and lifecycle;
- relationship side effects;
- cart physics;
- actor follow physics.

Physics solvers may be orchestrated by Entity callbacks but must not call scheduled Systems.

## Cart transport/cargo

Preserve:
- `R_CartDrivenBy` driver authority;
- `R_CartCargo` cargo authority;
- derived caches only when justified.

Separate scheduled intent/lifecycle from body physics solvers. Do not reintroduce transport lookup through unrelated Systems.

## Player input

Raw Godot input capture should only write controller intent/edges. Control-mode constraints belong in focused intent/state processing using authoritative focus/relationships.

Do not query Push/Transport Systems as service locators.

## Damage / Impact regression gate

Do not plan another broad rewrite merely because old R22.5 text mentioned `S_Damage`/`S_Impact`.

Verify only:
- no System-instance scan/service locator;
- no direct System-to-System calls;
- physics contact capture remains separate from typed damage resolution;
- throw lifetime/attribution remains Relationship-based;
- HP changes still flow through the typed damage pipeline.

## Acceptance

- no new direct project `S_* -> S_*` service calls;
- static-only helper classes are not registered/named as scheduled Systems;
- ownership stays Relationship-authoritative;
- behavior unchanged;
- stage uses static validation only.
