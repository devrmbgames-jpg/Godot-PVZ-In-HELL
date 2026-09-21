# Gameplay Context

## Ownership and entry points

`scenes/main_level.tscn` is the configured startup and project-owned prototype. It contains Player and three box instances (5/30/80kg).

The scene owns World, system groups, environment and an entity root named `Entityes`. World points to `../Entityes` and `Systems`.

## Scheduling and physics

- `scenes/main_level.gd` assigns ECS.world on ready; `_physics_process` invokes Input, Interaction, Physics, then GamePlay. Input edges/deltas belong to one physics tick.
- Physics scene nodes are S_Motion, S_Look, S_Jump and S_Crouch; Input contains S_PlayerInput. Interaction contains S_InteractionTargeting, S_Grab and O_GrabLifecycle (under Systems so GECS discovers it). GamePlay is empty.
- Do not infer solver execution from scene-node order: `entities/e_rigid_body_character.gd` explicitly calls S_Motion, S_Look and S_Crouch from `_integrate_forces`.
- Physical velocity/transform changes go through the body/PhysicsDirectBodyState3D. The entity exposes standing/crouching shapes, camera root and head axes for the systems.

## Task routing

| Task | Read contracts first | Implementation |
| --- | --- | --- |
| Input | `components/gameplay/c_controller.gd`, `components/input/c_player_input_controller.gd` | `systems/input/s_player_input.gd` |
| Movement / floor contacts / impulses | `components/motion/c_motion.gd` | `systems/motion/s_motion.gd` |
| Look | `components/motion/c_look.gd`, controller | `systems/motion/s_look.gd` |
| Jump | `components/motion/c_jump.gd`, controller | `systems/motion/s_jump.gd`, motion solver |
| Crouch | `components/motion/c_crouch.gd`, entity child references | `systems/motion/s_crouch.gd` |
| Interaction / physical props | `components/interaction/`, `components/motion/c_carry_load.gd`, [mechanic contract](../docs/physical_grab.md) | `systems/interaction/`, `observers/interaction/o_grab_lifecycle.gd`, `entities/props/e_grabbable.gd` |
| Attributes | `definitions/definition.gd`, `definitions/gameplay/def_attribute.gd` | `components/gameplay/c_attribute.gd`, `c_attribute_changed.gd`, `c_health.gd` |

Paths in this table are relative to `content/`; filenames without a directory share the preceding component directory.

## Current behavior and boundaries

S_PlayerInput writes motion/look directions and primary, secondary, crouch and jump actions into C_Controller. S_Jump requires C_Jump, C_Controller and C_Motion. A fresh jump press while grounded and control-enabled adds an upward impulse to C_Motion.pending_impulse; S_Motion consumes it during body integration. jump_force is an impulse in N*s, so the resulting velocity depends on body mass. Held buttons do not auto-jump on landing; airborne/disabled presses are not buffered. C_Jump.active is true only for the physics tick accepting the jump, and was_pressed tracks input history.

Health uses `definitions/gameplay/attributes/health.tres`. The presence of health data does not establish a combat system.

`entities/new_script.gd` is a separate CharacterBody3D template, not the canonical rigid-body character.

`tests/gut/test_s_jump.gd` covers impulse composition, held/repeated input, airborne/disabled input and invalid jump force through S_Jump.process. These unit tests do not validate full scene physics. For changes to GECS contracts, inspect the checked-out `addons/gecs/` source without modifying it.

## Grab ownership and input

The sole ownership authority is `box --C_HeldBy--> holder`. C_GrabControl.held_object is an observer-maintained reverse index, validated against that relationship on every read. Entity child references interaction_ray_cast and hold_anchor live on E_RigidBodyCharacter. The RayCast3D follows HeadX, is refreshed at the command boundary and is the range/line-of-sight authority.

S_Grab structural input commands use the GECS command buffer. O_GrabLifecycle forwards relationship events to S_Grab for pairwise collision exceptions, carry modifiers and cleanup. Body integration applies bounded forces/torques and breaks distant/invalid grips. Release preserves velocity; throw releases first, then adds mass * configured delta-velocity.

S_PlayerInput owns input edges and look_delta. Grab never clears them. During RMB rotation, input does not update direction_look and S_Look does not turn the head/body. Right stick uses axes 2/3; left stick remains movement. C_CarryLoad scales effective speed/acceleration without changing C_Motion base tuning or gravity.

S_InteractionTargeting outlines only the current enabled target and never replaces a pre-existing mesh overlay. GUT grab tests cover lifecycle, input priority, RayCast selection/highlighting, physical positioning/rotation, wall occlusion/blocking and main-scene wiring. See [controls and validation](../docs/physical_grab.md).
