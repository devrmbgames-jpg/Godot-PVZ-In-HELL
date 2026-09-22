# Gameplay Context

## Ownership and entry points

`scenes/main_level.tscn` is the configured startup and project-owned prototype. It contains Player, receiving zone, scanner, terminal and day stations. Morning supply creates eight physical parcels, including 5/30/80kg carry profiles.

The scene owns World, system groups, environment and an entity root named `Entityes`. World points to `../Entityes` and `Systems`.

## Scheduling and physics

- `scenes/main_level.gd` assigns ECS.world on ready; `_physics_process` invokes Input, Interaction, Physics, then GamePlay. Input edges/deltas belong to one physics tick.
- Physics scene nodes are S_Motion, S_Look, S_Jump and S_Crouch; Input contains S_PlayerInput. Interaction contains S_InteractionTargeting, S_Grab and O_GrabLifecycle (under Systems so GECS discovers it). GamePlay contains S_Damage before S_DayPhase; DaySession owns the singleton C_DayCycle. ShiftConsole and SleepPoint expose phase actions through contextual E/use.
- Do not infer solver execution from scene-node order: `entities/characters/e_rigid_body_character.gd` explicitly calls S_Motion, S_Look and S_Crouch from `_integrate_forces`.
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

S_Grab structural input commands use the GECS command buffer. O_GrabLifecycle forwards relationship events to S_Grab for pairwise collision exceptions, carry modifiers and cleanup. Body integration applies bounded translation forces and a direct angular-velocity servo and breaks distant/invalid grips. Release preserves velocity; throw releases first, then adds mass * configured delta-velocity.

S_PlayerInput owns input edges and look_delta. Grab never clears them. During RMB rotation, input does not update direction_look and S_Look does not turn the head/body. Right stick uses axes 2/3; left stick remains movement. C_CarryLoad scales effective speed/acceleration without changing C_Motion base tuning or gravity.

S_InteractionTargeting outlines only the current enabled target and never replaces a pre-existing mesh overlay. GUT grab tests cover lifecycle, input priority, RayCast selection/highlighting, physical positioning/rotation, wall occlusion/blocking and main-scene wiring. See [controls and validation](../docs/physical_grab.md).

## Package foundation (R01)

`entities/packages/package.tscn` inherits the physical box and uses `E_Package`; receiving instantiates this scene with data-defined masses and grab profiles. `define_components()` adds fresh `C_Package` identity and `C_PackageState` resources during World registration.

`DEF_Package` is immutable shared shipment data: number, description, comment, recipient key and bitmask tags (Normal=1, Fragile=2, Heavy=4, Liquid=8). Heavy+Fragile is valid. Runtime registration, scan, opening and damage enums live only in `C_PackageState`; defaults are Unregistered/NotScanned/Closed/Undamaged.

Receiving supplies deterministic package IDs; other dynamic instances generate a random 128-bit ID once at registration if none was supplied. Save/spawn code must restore that ID rather than regenerate it; Node paths and instance IDs are not persistent identity. `C_Package.package_id` is the registered identity; the entity export is initialization data. Future Customer work resolves `definition.recipient_id` into an authoritative `AssignedTo` relationship; no placeholder Customer Node is created.

## Contextual actions (R02)

`InteractionAction` resources are stateless availability/execution handlers supplied by `C_InteractionActionSet`. `InteractionActionResolver` resolves held-tool actions before physical grab actions, then aimed-target actions, then actor fallback (future attack). Within each scope, higher priority wins, then lexical action_id; keep IDs unique per slot. First-hit raycast remains target/LOS authority; commands revalidate LOS. Handlers must validate their own domain preconditions and handle a null target.

Held tools reserve configured slots (Primary=4 for Scanner, Secondary=8 for Marker) even with an unavailable target, preventing accidental throw/rotation. Alt bypasses held-tool actions for physical throw/rotation. E takes precedence over the other buttons on that tick. F/use and secondary edges are sampled by S_PlayerInput; only the producer writes input fields. `input_tick` prevents duplicate routing; zero is reserved for legacy direct/manual calls. Register future attacks as actor actions; never consume raw primary input in a second system.

S_Grab retains lifecycle/physics and invokes the action router through its command buffer. `C_Interactor.prompt_text` is a gameplay-generated snapshot consumed by `ui/interaction_hud.tscn`; the HUD only reads it; prompts/crosshair hide when the cursor is released, while phase status stays visible. Main mouse buttons are LMB/RMB. `tests/smoke/interaction_actions_smoke.tscn` is a standalone non-GUT validation scene for reservation, deduplication, modifier and priority behavior.

## Day phases (R03)

`DaySession` owns the only `C_DayCycle` (startup asserts uniqueness). `S_DayPhase` alone changes phase/day index; `DayTransitionRequest` captures the expected day and phase so duplicate/stale requests cannot skip phases. `DayPhaseAction` uses the R02 availability/execution contract, so contextual E prompts honor permissions.

Morning and Evening have no timeout. ShiftConsole starts the shift; a second use finishes Day only when remaining_customer_events is zero. The explicit empty-schedule policy is zero events and manual FinishShift; R11 will own the actual remaining-event count. SleepPoint is available only in Evening. Sleep enters Night; a separate gameplay tick advances to Morning and increments day_index once.

S_DayPhase emits night_started, morning_started and phase_changed. R21 can set night_ready=false synchronously on night_started, finish results/orders/save, then set it true to allow the next Morning. No save implementation exists yet. The HUD reads day/phase. Both stations are reachable from the starting area; `tests/smoke/day_cycle_smoke.tscn` drives their real raycast/E actions through a complete cycle and checks event gating, stale requests and the Night hold hook.

## Playtest controls and character contacts

Canonical controls: [docs/controls.md](../docs/controls.md). E first picks up when eligible, otherwise falls back to a target's USE action; F selects a distinct secondary action. Held tool > physical held object > target > actor fallback remains the scope order. Shared E/F edges execute once; prompt keys come from InputMap. Slot names INTERACT/USE denote primary/secondary interaction, not hardcoded keys.

CharacterMaterial has zero contact friction and the body replaces global linear damping with zero. S_Motion controls stopping/lateral friction and reads only floor material for ground traction, avoiding wall/ceiling friction without losing control acceleration. Preserve the user's collider/camera tuning. Held distance is 1.25 m. S_Grab sets angular velocity from shortest-arc rotation error / physics step (capped at max_rotation_speed); translation retains its physical spring. No transforms are teleported.

HUD phase panel stays visible even with released cursor; phase_changed drives 4-second announcements. A rendered preview is available via tests/smoke/hud_preview.tscn (requires rendering; writes ignored tests/artifacts/hud_preview.png).

## Damage/health (R04)

S_Damage is the sole gameplay damage/heal writer. C_Health.base means maximum HP; C_Health.value means current HP; defeated is terminal until a future explicit respawn/reset. C_AttributeChanged is not used for health; do not create a second current-health field.

Submit a typed DamageRequest with target, optional source, amount, operation (DAMAGE/HEAL) and damage_type (GENERIC/MELEE/IMPACT/EXPLOSION/TOXIC). S_Damage.submit queues an immutable snapshot into the active World's S_Damage; command-buffer resolution runs in GamePlay before day phase changes. Nonfinite/nonpositive requests and invalid/removed targets are rejected. Producers submit one request per intended event; reusing an event every frame intentionally repeats damage.

Every processed request emits damage_resolved(DamageResult), including rejection. The result carries the request, before/after values, applied amount and outcome. Lethal damage marks defeated before notifications, releases held relationships, disables motion control and clears targeting/highlights without UI participation. defeated(target, result) fires once; later damage/heal requests cannot revive the target.

Packages use C_PackageIntegrity (maximum/remaining), never actor health. The same pipeline adapts damage into C_PackageState.DAMAGED/DESTROYED and package outcomes; healing does not repair packages. R08/R09 will add physical damage thresholds and hazards. Customer actors will reuse C_Health and the same pipeline. Standalone validation: tests/smoke/damage_smoke.tscn.

## Morning supply (R05)

`definitions/gameplay/deliveries/morning_supply.tres` is a DEF_Delivery with eight ordered DEF_Package entries. Entry keys must be unique and nonempty within the supply. Definitions own recipient, description/comment, composable tags, hazard metadata, mass, carry/throw tuning and initial integrity. Hazards have no active effects yet (R08/R09).

`S_Receiving` runs after S_DayPhase in GamePlay. `C_Receiving` enqueues one BASE_SUPPLY ReceivingBatch per day, retaining incomplete older batches. Source distinguishes base supply from future PENDING_ORDER deliveries; no order fulfillment exists yet. Stable identity is `supply_key:day:entry_key`; delivery day is independent of registration day. Save work must restore both parcel IDs and receiving progress.

During Morning, receiving checks actual parcel collision shape against candidate markers before instantiating at most one body per physics tick. Occupied slots are skipped; a full zone retries every 0.25 seconds and displays a request to clear space. Existing parcels are never moved, deleted or reorganized. Later mornings resume pending supply before the new batch. Physics owns bodies after their initial spawn transform. Reprocessing an existing package ID advances progress without recreating it.

## Scanner and terminal (R06)

`E_DaySession` supplies a fresh singleton C_PackageLedger beside C_DayCycle. PackageRegistrationService is the sole registration writer; ScanAction invokes it at the interaction command boundary. The held scanner reserves LMB, revalidates first-hit LOS and a 3 m range, and rejects Night/inactive actors/invalid parcels. All writes (ledger row, runtime number, registered/scanned states) happen synchronously before feedback. IDs are ledger keys. Runtime registration numbers are global reusable warehouse slot numbers: store the base as a positive integer and display it as `№001`, `№002`, etc. Never prefix it with day/cycle and never reset allocation at a day boundary. A new registration receives the **smallest free positive number** not currently occupied by an active/undelivered Package. A Package keeps its number across days until it leaves the warehouse lifecycle; only then does that base number return to the free pool and become eligible for reuse. Repeat scans return the original number without a second row. Future fragile/oversized suffixes are presentation/metadata only and must not affect allocation, numeric ordering or reuse. Immutable shipment_number is not the runtime registration number.

Scanner feedback listens to PackageScanResult: successful and repeated scans beep and display the number. Terminal shows registrations for all active warehouse parcels across days, plus the last departure. `PackageRegistrationService.release_number(parcel)` accepts only authoritative `DELIVERED` state and marks its ledger record inactive; missing/deleted Nodes, damage and day changes never release reservations. Historical records keep their original base number even after reuse. The current Terminal is read-only: customer outcomes, declarations, value/penalty fields and disputes require their later domain stages. Closing with E/Esc restores cursor capture. The ledger is runtime-only pending R21 persistence. `label_printer.tres` defines a future printer; printing is not implemented.

Validation: `tests/smoke/receiving_scan_smoke.tscn` checks eight unique parcels and tags/hazards, pickup/scan/repeat/beep, range/target rejection, terminal opening, blocked delivery, resumed next-day supply, preserved old positions, stable cross-day numbers and smallest-free-number reuse after departure. Require its PASS marker; use `--quit-after 360` as the frame safety limit. Rendering with `-- --preview` saves an ignored screenshot under tests/artifacts. No new GUT suite was added.
