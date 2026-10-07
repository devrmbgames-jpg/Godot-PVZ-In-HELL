# Gameplay Architecture

Durable cross-system gameplay contracts. Read on demand only when a task crosses subsystem boundaries or the owning authority is unclear; focused work should start from the named code.

The complete target-core design is documented in `docs/project_core_architecture_proposal.md`. During Refactoring v2, this file remains the concise runtime contract while the proposal defines the migration destination.

## Runtime entry and scheduling

- Startup: `content/scenes/main_level.tscn`; glue: `content/scenes/main_level.gd`.
- `main_level.gd` assigns `ECS.world` and processes coarse groups in the order Input -> Interaction -> Physics -> GamePlay.
- Group/node order does not replace explicit `deps()` or physics-callback ownership.
- RigidBody transform/velocity authority stays in Godot/Jolt. Character/body integration is orchestrated from Entity physics callbacks through independent solvers; scheduled Systems must not be used as imperative physics services.
- Structural ECS mutation during iteration uses the pinned GECS-safe command/lifecycle path.

## ECS authority

- `C_*`: intrinsic/config/runtime state, or explicitly documented derived cache.
- `R_*`: authoritative live Entity-to-Entity ownership/session/binding.
- `S_*`: scheduled GECS behavior with a real query/process responsibility.
- `O_*`: discrete/reactive lifecycle/event behavior.
- services/solvers: reusable imperative domain logic or physics helpers that are not scheduled Systems.
- `DEF_*`: immutable/shared authored design data.
- UI is ordinary Godot `Control`/glue. It may read domain state/events and submit typed commands, but it is not scheduled through ECS and does not get UI-only Components.
- Entity Templates / `ET_*` Traits are authoring/compiler inputs. They do not tick and do not own mutable runtime gameplay state.
- Placed scenes remain visible physical/visual authoring objects in Godot Editor; Templates/Traits add gameplay composition without replacing scene authoring.

A System never calls another System as a service. Order is expressed through groups/`deps()`; cross-system communication uses Components, Relationships, typed requests/events/results.

Cross-domain intent should prefer typed Commands/Requests; successful authoritative outcomes are published as Events/Results. Do not use an Event as a hidden command or report an outcome before the authoritative mutation succeeds.

## Vertical domain target

Refactoring v2 migrates project-owned gameplay code from horizontal role roots toward `content/domains/<domain>/<role>/`, with genuine cross-domain infrastructure under `content/shared/<role>/`. Canonical role-folder spelling is enforced by `python utils/validate_domain_structure.py`; final architecture acceptance requires `--strict`, which rejects legacy horizontal gameplay roots.

Domains communicate through typed commands/events, stable public domain APIs, or explicit shared contracts. File moves alone are not a domain migration: ownership and dependencies must move with them.

## Input and interaction

- `S_PlayerInput` captures raw input into `C_Controller`.
- `S_PlayerIntent` converts controller input into gameplay-space motion/look according to current control focus.
- Targeting and presentation are separate: `S_InteractionTargeting` writes `C_Interactor.target/physics_target`; `S_InteractionHighlight` renders highlight from that state.
- `InteractionControlFocus` is the control-priority authority. Current priority order is MODAL > TRANSPORT/PUSH/CARRY as defined by the service > HANDS; drawing reserves its documented capture priority.
- Contextual actions route through `InteractionActionResolver`; do not add parallel raw E/F/LMB/RMB consumers for ordinary item interactions.
- Stable interaction contracts and control mapping live in `docs/physical_grab.md` and `docs/controls.md`.

## Grab, Push and Cart

- Held-item authority is `item --R_HeldBy--> actor`. `C_GrabControl.held_*` fields are derived reverse caches only.
- Push authority is `cart --R_PushedBy--> actor`; `C_PushControl` is derived/cache state.
- Cart driver/cargo authority is being normalized under R22.5; read the current code and the exact R22.5 milestone before changing those relationships.
- Raw/scriptless `RigidBody3D` Carry is supported through `C_PhysicsBodyRef` proxy Entities; the physical body remains physics authority.
- Carry mobility is Strength/mass driven. Detailed tuning, slots, anchors, collision exceptions, throws and rotation belong in `docs/physical_grab.md`.
- Cart movement/cargo behavior belongs in `docs/cart_transport.md`.

## Damage and Health

- `C_Health` is the sole HP authority.
- Damage enters through typed `DamageRequest` / `DamageRequestService` and is resolved by `O_Damage`; do not mutate HP from hazards/impact/UI directly.
- Impact capture and throw attribution are separate from HP resolution. Source veto such as `C_NoDamage` must not be bypassed by spawned effects.
- Living defeat and package destruction are different lifecycles. Do not infer removal merely from zero Health.
- Canonical contract: `docs/damage_impact.md`.

## Packages

- `DEF_Package` is shared shipment metadata/configuration. It does not select the physical package variant; `scene_variants` are chosen by Receiving.
- Runtime package identity is `C_Package.package_id`; Node paths/instance IDs are not persistent identity.
- `C_PackageState` owns registration/scan/open/damage condition.
- Concrete Package scenes own physical/presentation-specific configuration through scene-authored components.
- Destruction: `C_PackageDestruction.debris_scene` is authored on each concrete Package scene. `O_PackageDestruction` creates that debris, transfers pose/velocities, registers it, stores source `package_id + DEF_Package` in `C_PackageDebris`, emits `PackageDebrisSpawnedEvent`, then removes the original Package.
- Destruction does not release the warehouse registration number; domain departure/delivery owns that later lifecycle.

## Hazards

- Hazard effects are autonomous scenes. Package does not store a hazard enum/type.
- `DEF_Package.hazard_on_damaged` and `hazard_on_destroyed` are optional `PackedScene` hooks only.
- `O_PackageHazard` creates the short damaged effect from the Package.
- Destroyed effects start from replacement debris via `PackageDebrisSpawnedEvent` / `O_PackageDestroyedHazard`.
- `HazardSpawnService` + `O_HazardSpawn` are the generic factory path; definitions/lifetime/ownership live inside the hazard scene.
- Follow ownership uses `R_HazardFollow`. A `FollowOrigin + Despawn` residue disappears when its owner is removed.
- Explosion HP goes through Damage requests; physical blast impulse goes through `C_Motion.pending_impulse` for controlled characters and Godot/Jolt impulse for free RigidBodies.
- Canonical contract and tuning: `docs/hazards.md`.

## Day, Receiving and registration

- `E_DaySession` owns the singleton `C_DayCycle`; phase transitions use typed requests and the day-phase processor.
- Receiving spawns physical Package scenes from `DEF_Package.scene_variants`; it must preserve deterministic package identity and existing occupied space.
- Registration number allocation is warehouse-global for active/undelivered packages: smallest free positive base number, displayed as `№001` etc. Day changes do not reset it; only authoritative departure releases it.
- Scanner/terminal/receiving details live in their direct services/contracts and `PROJECT_INDEX.md` routes.

## Persistence and IDs

- Persistent/domain identity uses explicit stable IDs, never NodePath or instance ID.
- Runtime Entity references are not durable save identity.
- Relationships with durable meaning require an explicit persistence representation when R21 serialization is implemented; do not silently serialize live Object references.

## Validation routing

Use the narrowest relevant surface:
- repository structure: `python utils/validate_project_structure.py`;
- vertical domains during migration: `python utils/validate_domain_structure.py`;
- final vertical-domain gate: `python utils/validate_domain_structure.py --strict`;
- changed-file formatter/lint/static checks;
- Grab/input: `tests/gut/test_s_grab.gd`;
- Jump: `tests/gut/test_s_jump.gd`;
- feature smoke scenes under `tests/smoke/` via documented runner.

Do not run every suite after ordinary edits. See `AGENTS.md` for cadence.

## Package history identity and missed registration

- Customer-facing registration numbers (`№001`, etc.) remain reusable warehouse numbers and are not stable history identity.
- Every physically created package receives a hidden `C_Package.history_id` formatted as `<day>-<day-local number>-<5-char diagnostic code>`. The code is reversible: hazard class, physical size class, and mass in 0.1 kg encoded as three base36 characters. Do not show this ID in customer dialogue or the Terminal registry; it is reserved for package history/debugging.
- Package-pickup Customer events default to `requires_registered_package = true`: their NPC does not spawn until the requested Package has an active registration record, and blocked unregistered visits do not prevent shift completion. Events with another authored NPC purpose may explicitly opt out.
- On the next Morning, a due package-pickup visit that never became eligible because its Package is still unregistered is closed as LOST with `LossCause.MISSED_REGISTRATION` without spawning the NPC. R10 charges the dedicated data-driven missed-registration settlement (default 300%), not the cheaper honest LOST settlement (120%). Registered unresolved packages, not-yet-due visits, and opt-out events are not affected.
