# Gameplay Context

## Ownership and entry points

`scenes/main_level.tscn` is the configured startup and project-owned prototype. It contains Player, receiving zone, scanners, marker, six numbered physical shelf compartments, terminal and day stations. Morning supply creates eight physical parcels, including 5/30/80kg carry profiles.

The scene owns World, system groups, environment and an entity root named `Entityes`. World points to `../Entityes` and `Systems`.

## Scheduling and physics

Warehouse `push_cart.tscn` uses a dedicated CharacterBody3D transport, separate from unchanged puzzle S_Push. S_CartTransport owns grounded forward/reverse/turning on the cart physics callback; S_Motion delegates driver following while TRANSPORT capture is active. Settled rigid cargo uses bounded custom-integration assistance through S_CartCargo and restores ordinary physics on pickup/removal. Physical authority, cleanup, controls and supported terrain are documented in [cart_transport.md](../docs/cart_transport.md).

- `scenes/main_level.gd` assigns ECS.world on ready; `_physics_process` invokes Input, Interaction, Physics, then GamePlay. Input edges/deltas belong to one physics tick.
- Physics scene nodes are S_Motion, S_Look, S_Jump and S_Crouch; Input contains S_PlayerInput. Interaction contains S_InteractionTargeting, S_Grab and O_GrabLifecycle (under Systems so GECS discovers it). GamePlay contains O_Damage for typed damage events and S_DayPhase; DaySession owns the singleton C_DayCycle. ShiftConsole and SleepPoint expose phase actions through contextual E/use.
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

`tests/gut/test_s_jump.gd` covers impulse composition, held/repeated input, airborne/disabled input and invalid jump force through S_Jump.process. These unit tests do not validate full scene physics. For changes to GECS contracts, inspect the checked-out `addons/gecs/` source without modifying it.

## Grab ownership, capture and Push (R06.1)

The sole held-item authority is `item --C_HeldBy(slot)--> actor`. CARRY, RIGHT_HAND and LEFT_HAND have independent validated reverse caches in C_GrabControl. Allowed hand flags replace fixed item hands; anchors come from the runtime relation. Only Carry affects C_CarryLoad. Replacement validates target/slot/body/LOS before releasing the old occupant. RayCast excludes the actor and all three held objects.

InteractionControlFocus owns a registry of unique capture tokens (including nested captures from the same owner): MODAL > PUSH > CARRY > HANDS. Carry/Push relations and each Terminal release only their own token. Hand ownership remains intact while authored lowered anchors suspend hand control; the last release restores normal authored Arm anchors. Anchor transitions reset velocity sampling and allow a bounded physical transition. See [physical_grab.md](../docs/physical_grab.md) for solver and break-distance contracts.

S_Grab commands flush after ECS iteration; O_GrabLifecycle applies collision exceptions, sleeping state, Carry penalties and idempotent cleanup. Physics bodies remain transform/velocity authority. Release preserves inertia; throw adds mass * configured delta-velocity. Manual rotation is configured per item (enabled, FREE/Y_ONLY offset, pickup reset); Scanner disables it and Bucket uses Y_ONLY. No held transforms are teleported.

Push is separate: C_Pushable + `cart --C_PushedBy--> actor`, with C_PushControl as derived cache and O_PushLifecycle for lifecycle. S_Push validates front/range/LOS and actor/cart availability. W drives fixed forward speed, A/D fixed yaw speed; E/S ends without reverse traction. E_PushableBody integrates cart velocity and S_Motion delegates planar actor handle-follow to S_Push. Modal capture pauses motors without releasing Push or hands. Authored PushCart is in the main scene, outside starting geometry.

Interaction scheduling is targeting -> Push validation -> Grab/resolver, within Input -> Interaction -> Physics -> GamePlay. S_PlayerInput alone writes edges/move_axis/look_delta; Push captures camera heading, rotation consumes mouse delta without also rotating the camera. S_InteractionTargeting owns highlighting and restores previous overlays.

## Package foundation (R01)

`entities/packages/package.tscn` inherits the physical box and uses `E_Package`; receiving instantiates this scene with data-defined masses and grab profiles. `define_components()` only creates spawn-specific C_Package identity. C_PackageState and C_Health are scene-authored; receiving clones individual grab tuning without replacing those components. O_PackageConditionSetup initializes definition Health and impact profile once for both authored and received packages.

`DEF_Package` is immutable shared shipment data: number, description, comment, recipient key and bitmask tags (Normal=1, Fragile=2, Heavy=4, Liquid=8). Heavy+Fragile is valid. Runtime registration, scan, opening and damage enums live only in `C_PackageState`; defaults are Unregistered/NotScanned/Closed/Undamaged.

Receiving supplies deterministic package IDs; other dynamic instances generate a random 128-bit ID once at registration if none was supplied. Save/spawn code must restore that ID rather than regenerate it; Node paths and instance IDs are not persistent identity. `C_Package.package_id` is the registered identity; the entity export is initialization data. Future Customer work resolves `definition.recipient_id` into an authoritative `AssignedTo` relationship; no placeholder Customer Node is created.

## Contextual actions (R02/R06.1)

DEF_InteractionAction definitions are stateless handlers in C_InteractionActionSet. InteractionActionResolver selects one action per input through capture priority; within a source, higher priority wins with a documented lexical action_id tie-break. Commands revalidate target LOS. Handlers validate their own domain and tolerate a null target.

E/F select free/replacement hands using state and C_GrabControl.swap_hand_controls; Carry capacity is independent. Tool PRIMARY means item use, mapped to LMB/RMB according to its physical hand; Alt throws that mapped hand. An occupied hand reserves input even without a valid action target. Carry owns E release/LMB throw/RMB rotate; generic active-hand rotation uses R only without hand-use input. G short-release drops Carry -> Left -> Right; configurable long-press opens a placeholder and suppresses drop. E/F/G and capture transitions cannot leak the same input into lower-priority actions. input_tick prevents duplicate routing; zero supports legacy direct/manual calls.

C_Interactor.prompt_text is a gameplay-generated snapshot read by interaction_hud.tscn. InputMap provides E/F/mouse labels; phase status stays visible with free cursor. New attack/tool behavior belongs in this resolver contract, never in a parallel consumer of raw mouse input. Full player mapping: [controls.md](../docs/controls.md).

## Day phases (R03)

`DaySession` owns the only `C_DayCycle` (startup asserts uniqueness). `S_DayPhase` alone changes phase/day index; `DayTransitionRequest` captures the expected day and phase so duplicate/stale requests cannot skip phases. `DEF_DayPhaseAction` uses the R02 availability/execution contract, so contextual E prompts honor permissions.

Morning and Evening have no timeout. ShiftConsole starts the shift; a second use finishes Day only when remaining_customer_events is zero. The explicit empty-schedule policy is zero events and manual FinishShift; R11 will own the actual remaining-event count. SleepPoint is available only in Evening. Sleep enters Night; a separate gameplay tick advances to Morning and increments day_index once.

S_DayPhase emits night_started, morning_started and phase_changed. R21 can set night_ready=false synchronously on night_started, finish results/orders/save, then set it true to allow the next Morning. No save implementation exists yet. The HUD reads day/phase. Both stations are reachable from the starting area; `tests/smoke/day_cycle_smoke.tscn` drives their real raycast/E actions through a complete cycle and checks event gating, stale requests and the Night hold hook.

## Playtest controls and character contacts

Canonical controls: [docs/controls.md](../docs/controls.md). E first picks up when eligible, otherwise falls back to a target's USE action; F selects a distinct secondary action. Capture priority and physical hand mapping follow R06.1 above. Shared E/F edges execute once; prompt keys come from InputMap. Slot names INTERACT/USE denote primary/secondary interaction, not hardcoded keys.

CharacterMaterial has zero contact friction and the body replaces global linear damping with zero. S_Motion controls stopping/lateral friction and reads only floor material for ground traction, avoiding wall/ceiling friction without losing control acceleration. Preserve the user's collider/camera tuning. Held distance is 1.25 m. S_Grab sets angular velocity from shortest-arc rotation error / physics step (capped at max_rotation_speed); translation retains its physical spring. No transforms are teleported.

HUD phase panel stays visible even with released cursor; phase_changed drives 4-second announcements. A rendered preview is available via tests/smoke/hud_preview.tscn (requires rendering; writes ignored tests/artifacts/hud_preview.png).

## Damage/health (R04)

O_Damage is the sole gameplay damage/heal writer. C_Health extends C_AttributeChanged: base is authored HP, value is computed maximum HP and current is remaining HP. Depletion is terminal until an explicit respawn/reset.

DamageRequestService.submit publishes a copied typed DamageRequest to O_Damage through a World event, without a System service locator. Null/removed/non-Health targets are rejected at entry. O_Damage validates amounts and current Health, applies the source-side C_NoDamage veto (BLOCKED outcome, incoming damage and healing unaffected), and commits depletion before Health property notifications. The optional builder uses the same submit path.

Processed requests publish typed World events under DamageResult.EVENT, including rejection and blocked outcomes. Positive Health crossing zero commits HEALTH_DEPLETED once before notifications. O_HealthLifecycle handles only C_Living: C_Death, grip release and control disable; the targeting processor clears its own selection/highlight on the next tick. O_PackageDamage handles package condition independently and keeps destroyed physical entities alive. Healing restores non-depleted HP but does not undo package condition; depletion remains terminal.

Packages and actors use the same C_Health arithmetic. Package definitions initialize maximum_health; there is no second integrity authority. Standalone damage_smoke was adapted to the shared contract; R08 runtime validation is user-owned.


## Morning supply (R05)

`definitions/gameplay/deliveries/morning_supply.tres` is a DEF_Delivery with eight ordered DEF_Package entries. Entry keys must be unique and nonempty within the supply. Definitions own recipient, description/comment, composable tags, hazard metadata, mass, carry/throw tuning and initial integrity. Hazards have no active effects yet (R08/R09).

`S_Receiving` runs after S_DayPhase in GamePlay. `C_Receiving` enqueues one BASE_SUPPLY ReceivingBatch per day, retaining incomplete older batches. Source distinguishes base supply from future PENDING_ORDER deliveries; no order fulfillment exists yet. Stable identity is `supply_key:day:entry_key`; delivery day is independent of registration day. Save work must restore both parcel IDs and receiving progress.

During Morning, receiving checks actual parcel collision shape against candidate markers before instantiating at most one body per physics tick. Occupied slots are skipped; a full zone retries every 0.25 seconds and displays a request to clear space. Existing parcels are never moved, deleted or reorganized. Later mornings resume pending supply before the new batch. Physics owns bodies after their initial spawn transform. Reprocessing an existing package ID advances progress without recreating it.

## Scanner and terminal (R06)

Marker drawing uses the existing hand-use resolver and an independent DRAWING capture below MODAL. `S_Marker` runs after S_Grab; first-hit rays produce bounded package-local `C_PackageMarks` strokes, rendered by a child mesh. E/Esc restores look; loss of ownership cancels capture; authoritative package destruction clears ink. Registration and physical storage remain independent. Full ownership/input/R21 persistence contract: [package_marking.md](../docs/package_marking.md).

`E_DaySession` supplies a fresh singleton C_PackageLedger beside C_DayCycle. PackageRegistrationService is the sole registration writer; DEF_ScanAction invokes it at the interaction command boundary. The held scanner reserves LMB, revalidates first-hit LOS and a 3 m range, and rejects Night/inactive actors/invalid parcels. All writes (ledger row, runtime number, registered/scanned states) happen synchronously before feedback. IDs are ledger keys. Runtime registration numbers are global reusable warehouse slot numbers: store the base as a positive integer and display it as `№001`, `№002`, etc. Never prefix it with day/cycle and never reset allocation at a day boundary. A new registration receives the **smallest free positive number** not currently occupied by an active/undelivered Package. A Package keeps its number across days until it leaves the warehouse lifecycle; only then does that base number return to the free pool and become eligible for reuse. Repeat scans return the original number without a second row. Future fragile/oversized suffixes are presentation/metadata only and must not affect allocation, numeric ordering or reuse. Immutable shipment_number is not the runtime registration number.

Scanner feedback listens to PackageScanResult: successful and repeated scans beep and display the number. Terminal shows registrations for all active warehouse parcels across days, plus the last departure. `PackageRegistrationService.release_number(parcel)` accepts only authoritative `DELIVERED` state and marks its ledger record inactive; missing/deleted Nodes, damage and day changes never release reservations. Historical records keep their original base number even after reuse. The current Terminal is read-only: customer outcomes, declarations, value/penalty fields and disputes require their later domain stages. Closing with E/Esc restores cursor capture. The ledger is runtime-only pending R21 persistence. `label_printer.tres` defines a future printer; printing is not implemented.

Validation: `tests/smoke/receiving_scan_smoke.tscn` checks eight unique parcels and tags/hazards, pickup/scan/repeat/beep, range/target rejection, terminal opening, blocked delivery, resumed next-day supply, preserved old positions, stable cross-day numbers and smallest-free-number reuse after departure. Require its PASS marker; use `--quit-after 360` as the frame safety limit. Rendering with `-- --preview` saves an ignored screenshot under tests/artifacts. No new GUT suite was added.

## R08 impact and package condition

Canonical contract: [damage_impact.md](../docs/damage_impact.md). ImpactCaptureSolver writes runtime body inboxes; S_Impact drains their iterate query and resolves independent contact episodes, submitting typed requests to O_Damage. S_ThrowLifetime owns its own query. No Damage/Impact System service locator or cross-System calls. Package profiles, severity protection, continuous liquid tilt and explicit F/open share typed lifecycle hooks. PackageConditionView is read-only. Runtime acceptance is user-owned; [manual checks](../docs/r08_manual_validation.md).
