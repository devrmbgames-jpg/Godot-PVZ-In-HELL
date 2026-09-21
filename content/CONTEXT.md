# Gameplay Context

## Ownership and entry points

`scenes/main_level.tscn` is the configured startup and project-owned prototype. It contains Player and three box instances (5/30/80kg).

The scene owns World, system groups, environment and an entity root named `Entityes`. World points to `../Entityes` and `Systems`.

## Scheduling and physics

- `scenes/main_level.gd` assigns ECS.world on ready; `_physics_process` invokes Input, Interaction, Physics, then GamePlay. Input edges/deltas belong to one physics tick.
- Physics scene nodes are S_Motion, S_Look, S_Jump and S_Crouch; Input contains S_PlayerInput. Interaction contains S_InteractionTargeting, S_Grab and O_GrabLifecycle (under Systems so GECS discovers it). GamePlay contains S_DayPhase; DaySession owns the singleton C_DayCycle. ShiftConsole and SleepPoint expose phase actions through F/use.
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

## Package foundation (R01)

`entities/props/package.tscn` inherits the physical box and uses `E_Package`; the main scene's three boxes now use this scene without changing masses or grab profiles. `define_components()` adds fresh `C_Package` identity and `C_PackageState` resources during World registration.

`DEF_Package` is immutable shared shipment data: number, description, comment, recipient key and bitmask tags (Normal=1, Fragile=2, Heavy=4, Liquid=8). Heavy+Fragile is valid. Runtime registration, scan, opening and damage enums live only in `C_PackageState`; defaults are Unregistered/NotScanned/Closed/Undamaged.

Authored package IDs are explicit in the main scene. Dynamic instances generate a random 128-bit ID once at registration if none was supplied. Save/spawn code must restore that ID rather than regenerate it; Node paths and instance IDs are not persistent identity. `C_Package.package_id` is the registered identity; the entity export is initialization data. Future Customer work resolves `definition.recipient_id` into an authoritative `AssignedTo` relationship; no placeholder Customer Node is created.

## Contextual actions (R02)

`InteractionAction` resources are stateless availability/execution handlers supplied by `C_InteractionActions`. `InteractionActions` resolves held-tool actions before physical grab actions, then aimed-target actions, then actor fallback (future attack). Within each scope, higher priority wins, then lexical action_id; keep IDs unique per slot. First-hit raycast remains target/LOS authority; commands revalidate LOS. Handlers must validate their own domain preconditions and handle a null target.

Held tools reserve configured slots (Primary=4 for Scanner, Secondary=8 for Marker) even with an unavailable target, preventing accidental throw/rotation. Alt bypasses held-tool actions for physical throw/rotation. E takes precedence over the other buttons on that tick. F/use and secondary edges are sampled by S_PlayerInput; only the producer writes input fields. `input_tick` prevents duplicate routing; zero is reserved for legacy direct/manual calls. Register future attacks as actor actions; never consume raw primary input in a second system.

S_Grab retains lifecycle/physics and invokes the action router through its command buffer. `C_Interactor.prompt_text` is a gameplay-generated snapshot consumed by `ui/interaction_hud.tscn`; the HUD only reads it and hides when the cursor is released. Main mouse buttons are LMB/RMB. `tests/smoke/interaction_actions_smoke.tscn` is a standalone non-GUT validation scene for reservation, deduplication, modifier and priority behavior.

## Day phases (R03)

`DaySession` owns the only `C_DayCycle` (startup asserts uniqueness). `S_DayPhase` alone changes phase/day index; `DayTransitionRequest` captures the expected day and phase so duplicate/stale requests cannot skip phases. `DayPhaseAction` uses the R02 availability/execution contract, so F prompts honor permissions.

Morning and Evening have no timeout. ShiftConsole starts the shift; a second use finishes Day only when remaining_customer_events is zero. The explicit empty-schedule policy is zero events and manual FinishShift; R11 will own the actual remaining-event count. SleepPoint is available only in Evening. Sleep enters Night; a separate gameplay tick advances to Morning and increments day_index once.

S_DayPhase emits night_started, morning_started and phase_changed. R21 can set night_ready=false synchronously on night_started, finish results/orders/save, then set it true to allow the next Morning. No save implementation exists yet. The HUD reads day/phase. Both stations are reachable from the starting area; `tests/smoke/day_cycle_smoke.tscn` drives their real raycast/F actions through a complete cycle and checks event gating, stale requests and the Night hold hook.
