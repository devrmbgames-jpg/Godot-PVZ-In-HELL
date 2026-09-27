# R22.5 M3 — Physics Solvers and Scheduling

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
