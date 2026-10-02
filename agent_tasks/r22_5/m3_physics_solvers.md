# R22.5 M3 — Physics Solvers and Scheduling

Status: **DONE**
Owner task: [R22.5](../roadmap_22_5_gecs_architecture_polish.md)

## Task state

### Goal
Make scheduled GECS Systems and callback-driven physics solvers/helpers truthfully separated while preserving body authority.

### Current
Current callbacks/solvers/groups audited; historical Motion/Look/Cart pseudo-System issues already resolved. Shared crouch head geometry explicitly classified as gameplay glue while preserving legacy class/scene/exported paths. Broad physics collider/material lookup has explicit concrete annotations. Contract: `docs/gecs_architecture.md`. Next: final M4 remaining owners audit and bounded runtime validation.

### Validation
Static direct source/hierarchy audit and diff review PASS. Main groups are Input → Interaction → Physics → GamePlay; deps express local order. Callback helpers extend RefCounted, and Motion does not dispatch Push/Transport. No M3 GUT/engine run; final runtime budget remains M4.

### Owner QA / blockers
No implementation blocker. Owner runtime/rendered acceptance remains in feature tasks and R23.

## Verified classification / decisions

- `E_RigidBodyCharacter` orchestrates its physics callback; independent CharacterMotion/Look, PushActor and CartDriver helpers own contributions. `E_GrabbableBody` orchestrates impact/cargo/hold handling; `E_TransportCart` owns CharacterBody stepping.
- `S_Jump` writes pending impulse state consumed by the motion callback. Crouch collision transitions remain scheduled gameplay, not presentation.
- **R3 FIXED:** `S_CrouchPresentation` claimed camera-only behavior, but authored `camera_root = HeadY/HeadX/HeadRoot` also parents InteractionRay, Holder, hand and lowered-hand anchors. Source/docs now classify this as shared gameplay geometry. Its exported/node/class/resource paths and interpolation are deliberately preserved; disabling it cannot be used as a visual-only toggle. No gameplay or physics redesign.
- Generic raw rigid bodies keep their existing explicit pre-physics force/velocity hold contract; do not pretend their callback can be replaced by injecting a script.
- No additional cleanup group, sub-System lifecycle or callback-only System is needed. Independent scheduled queries already have actual work.

---

## Goal

Make class identity truthful: real scheduled work remains `System`; callback-driven physics math becomes non-System solvers/helpers.

## Motion / Look / Crouch

Verify current code before editing.

Target:
- character physics callback is the orchestration boundary;
- locomotion/look/crouch physics contributions are independent helpers/solvers when they have no real GECS query/process responsibility;
- Motion does not dispatch Push/Transport;
- camera-only crouch interpolation is presentation unless gameplay demonstrably depends on it;
- gameplay-critical head/raycast/anchor/collision child references stay Entity glue.

Do not split cohesive math just for file-size metrics.

## Choosing System vs sub-system vs service

Use a separate System when responsibility:
- is independently schedulable;
- owns a distinct component set;
- has independent lifecycle/order;
- should be enabled/disabled independently.

Use GECS `sub_systems()` when one cohesive feature owns several distinct queries and a shared lifecycle.

Use a non-System service/solver when code is:
- pure calculation;
- imperative domain lookup rather than repeated ECS iteration;
- scene/physics utility without ECS scheduling ownership.

Every scheduled System/sub-system still needs one focused query and no System-service calls.

## SystemGroups

Preserve the coarse scene groups:
- Input;
- Interaction;
- Physics;
- GamePlay.

Use group placement + `deps()` for order. Never encode order by directly calling another System.

Add a cleanup group only if an explicit pending-delete lifecycle requires it.

## Physics authority

- Godot/Jolt bodies own transform/velocity.
- `PhysicsDirectBodyState3D` remains inside the body callback.
- Physics solvers mutate only their owned contribution.
- Scheduled ECS logic communicates intent/state, not direct cross-System physics commands.

## Acceptance

- no registered no-op/pseudo-System nodes;
- callback-only helpers are not `extends System`;
- body callback remains the only physics orchestration exception;
- gameplay/presentation split is explicit;
- scene groups/deps express scheduled order.
