# Refactoring v2.21 — Grab, Push, Carry и physical slots

Status: **DONE**

Зависимости: [20_interaction_input.md](20_interaction_input.md).

## Goal

Разделить крупные interaction services по реальным ролям и убедиться, что scheduled state progression остаётся в Systems/Observers, а imperative operations — в Services.

## Scope

- `GrabService`;
- `PushService`;
- `PhysicalSlotService`;
- anchoring/cart/carry related services;
- lifecycle Observers;
- Relationships `R_HeldBy`, `R_PushedBy` и derived caches.

## Constraints

Не ломать physics ownership и текущие Relationship authorities.
Не переносить physics callback solvers в ECS ради единообразия.

## Acceptance

Каждый крупный interaction Service имеет одну объяснимую роль.
Scheduled behavior не скрыт внутри Service.
Структурные add/remove операции используют корректный GECS lifecycle/CommandBuffer path.

## Validation

`test_s_grab.gd` и профильные cart/slot tests, parser.

## Current / Next

DONE 2026-10-08. Далее [22 — Motion/physics](22_motion_physics.md).

- `GrabService` retains explicit acquire/release/lookup and reversible `R_HeldBy` lifecycle/cache operations. `S_Grab` owns generic-body slot traversal and queues structural retirement with captured binding identity. `E_GrabbableBody` calls `GrabPhysicsSolver` directly for native holding; force/rotation/throw facades removed, profile snapshot initialized at grip commit, physical transform authority preserved.
- `S_Push` owns scheduled participation validation and rejects stale queued `R_PushedBy` checks. Service retains binding transactions/reactions and derived cache; no forwarding `validate_actor` scheduler.
- `S_AnchorStability` owns rest accumulation; `AnchoringRules` owns pure motion/config rules. Anchor/unfix/support-cluster checks remain explicit transactions.
- `S_CartCargo` owns membership/support/settling progression from the latest completed Jolt space at Interaction stage before this frame's cart callback. Sampling is once per physics frame and revalidates cart/Component/frame identity. Native cart drive and independent cargo-follow callback solvers retain motion; `CartCargoService` retains explicit bind/release and reversible relationship effects, `CartCargoGeometry` the support query. Removed nested cargo update from `CartDriveSolver`.
- `OpenableMotionSolver` owns fraction/transform calculations; request/report attribution stays explicit and joint callback owns actual physical motion. All callers migrated without wrappers.
- Physical slots, carry placement, transport driver and proxy lifecycle reviewed: live relationships are authoritative, caches derived; one-shot add/remove paths retain native GECS observer reactions and reversible body policies. No save-visible path/schema change; transient frame receipt is omitted from snapshots.

## Validation evidence

- Godot parser: **25 changed project-owned files PASS**, final **3-file PASS**, zero failures.
- Initial focused GUT: **170/170**, 1126 assertions (`refactoring_v2_21_physics_gut.log`). Final extended surfaces: **126/127** initially; sole failure was historical eight-parcel main fixture versus authored five-package cap. Corrected fixture reads `DEF_Delivery.maximum_batch_packages`, checks actual registered owners and keeps mass/pickup/rotation/release assertions; final main fixture **1/1, 75 assertions PASS** (`refactoring_v2_21_main_gut.log`). Changed native callback plus five new World lifetime/physics regressions: `test_s_grab.gd` **91/91 PASS** (`refactoring_v2_21_final_grip_gut.log`); that intermediate run exposed incorrect fixture node lookup paths, corrected and verified by final main run. Openable, slots, native CharacterBody, impact and current-format persistence surfaces PASS in extended run.
- Five added regressions exercise real World owners: generic body moves by force without teleport, stale invalid-grip retirement preserves replacement binding/cache/exception, queued push check preserves replacement session then current check retires invalid session, cargo Component replacement and physical-frame expiry discard old samples.
- Actual Jolt cart headless smoke **PASS** (`cart_transport-20261008-132440927.log`): three settled/stacked cargos, turn/reverse, ramps/uneven ground/wall blocking, pickup and disable release. Main-level headless input/grab/native callback smoke **PASS** (`interaction_actions-20261008-132735768.log`). No rendered gameplay or subjective visual QA.
- Architecture **PASS** (2 remaining findings owned by 25), project structure, persistence baseline and roadmap preflight **PASS**. Removed API search: no runtime/test callers. `git diff --check` PASS.
- Acceptance **PASS**; no owner QA or blocker required for this behavior-preserving architecture slice.
