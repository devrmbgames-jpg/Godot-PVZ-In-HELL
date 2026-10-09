# Gameplay Architecture

Durable cross-system gameplay contracts. Read on demand only when a task crosses subsystem boundaries or the owning authority is unclear; focused work should start from the named code.

The complete target-core design is documented in [Project Core Architecture](../docs/project_core_architecture_proposal.md). This file owns the canonical role and ownership rules; the proposal describes the migration destination. These rules constrain new work and migration acceptance; they do not assert that every legacy execution path has already migrated.

## Runtime entry and scheduling

- Startup: `content/scenes/main_level.tscn`; glue: `content/scenes/main_level.gd`.
- `main_level.gd` assigns `ECS.world` and processes coarse groups in the order Input -> Interaction -> Physics -> GamePlay.
- Group/node order does not replace explicit `deps()` or physics-callback ownership.
- RigidBody transform/velocity authority stays in Godot/Jolt. Character/body integration is orchestrated from Entity physics callbacks through independent solvers; scheduled Systems must not be used as imperative physics services.
- Structural ECS mutation during iteration uses the pinned GECS-safe command/lifecycle path.
- Registered disabled actors retain structural tracking in `GameWorld`: native disable facts/process shutdown remain intact, while Component/Relationship mutations keep the pinned archetype index current. Disabled participation does not end persistent lifecycle ownership; restore and morning fixup may mutate dormant bodies before reactivation. The project-owned override reconnects the six pinned structural callbacks; it introduces no secondary index or addon modification.

## Canonical roles and ownership

Choose a role by its responsibility, not its current class suffix. A misleading name is migration debt: rename/move it with its callers in the owning task rather than treating the name as permission to retain the wrong ownership.

| Role | Owns | Boundary |
| --- | --- | --- |
| `C_*` | Intrinsic/config/runtime state, or an explicitly documented derived cache | Data only; no scheduled behavior. Mark cache source and writer. |
| `R_*` | Authoritative live Entity-to-Entity ownership, session or binding | One binding authority; reverse lookups/caches do not become another owner. This role holds even when GECS uses the Component base. |
| `S_*` | Scheduled GECS behavior: query, iteration, temporal progression, cadence and ordering | One coherent scheduled responsibility; use groups/`deps()` rather than calling another System. |
| `O_*` | Discrete lifecycle/event reactions and transitions | Respond to an actual change/request; do not hide a regular polling loop in a reaction. |
| `*Service` | Explicit synchronous domain operation, transaction, lookup or factory boundary | May mutate the operation's owned C/R state; does not own a recurring tick, broad scheduled iteration or a second execution graph. |
| `*Rules` / `*Calculation` | Predominantly pure validation, decisions and calculations over explicit inputs | Return decisions/values; the owning handler commits gameplay transitions. |
| `*Geometry` | Spatial calculations and explicit ray/shape/world queries | No ownership of gameplay lifecycle, timer progression or recurring actor iteration. |
| `*Solver` | An isolated reusable algorithm, including required engine-bound physics integration | An engine callback may apply its owned physical contribution; a Solver is not an alternative gameplay scheduler. |
| `*Presentation` | Visual/UI representation of authoritative state | Owns presentation state only; gameplay changes enter through the owning request/API. |
| `*Factory` | Construction/materialization for an explicit creation operation | No recurring post-spawn lifecycle; prepare/validate before registration and hand runtime behavior to Systems/Observers. |
| Entity / engine glue | Identity, registration/lifetime and thin scene/callback bindings | Godot bodies own physical transform/velocity; glue does not become a parallel gameplay model. |
| `DEF_*` | Immutable/shared authored design data | Runtime mutable state belongs to C/R, not a shared Definition. |
| UI (`Control`, HUD, menus) | Godot layout, focus and presentation glue | May read domain state/facts and submit typed intent; no UI-only Components/Systems or gameplay authority. |
| Entity Templates / `ET_*` Traits | Authoring/compiler recipes for runtime composition | Do not tick or own mutable gameplay state; materialization produces ordinary C/R contracts. |
| Typed Commands / Requests | Intent submitted to an authoritative handler | Submission is not proof of completion; the boundary declares acceptance/defer/rejection semantics. |
| Typed Events / Results | Authoritative outcome, including explicit rejection where applicable | Publish a fact only after the mutation it describes is committed and visible. An Event is not a hidden command. |

### State authority

Components and Relationships remain the gameplay authority. Typed records/Resources nested in an ECS-owned Component may form one aggregate with an explicit owner and writer per field; their Resource type alone does not create another runtime model. Mark derived caches, immutable identity mirrors and terminal history. Reject competing mutable copies in services, Blackboard, Dialogue, UI or the Node tree.

A Relationship either guarantees its target remains live while the binding exists, or its single lifecycle/resolving boundary handles stale endpoints. Do not replace the live binding with independently mutable Entity references in Components or service registries.

District calendar goals, phase completion and morning preparation are owned by O_DistrictLifecycle. S_District bootstraps only missing/restored calendar facts before customer/day/native-decision/intent consumers. Population registry/materialization and physical participation are explicit operations. Native goal completion and night capture wait for actual typed receipts; retained dormant bodies remain lifecycle targets. Derived calendar caches are not persisted.

Native NPC cadence, footsteps, perception, traits, decisions and noise ageing are explicit Systems with one transient captured due interval in C_NpcDecision. NpcDecisionReady commits after sampled sensing/traits and before native BT/role-clock consumers. Queued stages reject replaced components or calendar/participation changes; decision revalidates after synchronous ready reactions. NpcBrainService is only a LimboAI runtime adapter.

After native BT, S_NpcRoute consumes the same captured interval for route clocks/progress/cleanup. S_NpcRoutePlanning owns the district FIFO and one budget per native physics frame before noise/combat/navigation consumers. NpcRouteSolver calculates bounded paths/risk, while S_NpcIntent consumes waypoints and Godot integrates the body. Queued planning rejects replaced aggregates and stale participation/intent.

### Choosing execution ownership

1. Required engine timing comes first: work that must use `PhysicsDirectBodyState3D` in `_integrate_forces` stays in that callback's Entity glue and independent non-System Solvers.
2. Regular query/iteration, cooldown progression or per-frame ordering belongs to a System. For example, a System that queries actors and advances their cooldown using `delta` owns that step; forwarding the entire step to `SomeService.tick(delta)` does not transfer it to a legitimate Service.
3. A discrete request or lifecycle change belongs to its Observer/event handler or explicit synchronous domain operation, according to the delivery contract.
4. A reusable calculation/spatial algorithm belongs to Rules/Calculation/Geometry/Solver; an explicit transaction/lookup/construction belongs to Service/Factory.

A System may be large when it implements one coherent scheduled responsibility. Do not extract scheduled behavior into a Service merely to reduce file size. If responsibilities or cadence differ, split into Systems with explicit `deps()` and data flow. A System never calls another System as an imperative service/helper.

A narrow Service may call another Service or Rules helper within one synchronous operation. That composition must not introduce regular service ticks, hidden subsystem ordering or a frame-by-frame scheduler graph. Deferred structural work has an explicit commit/flush point; publishing a completed outcome cannot rely on enqueue alone.

Physics solvers called from a body's callback read their owned state/relationships and apply only their owned contribution. They do not call each other or Systems, and are not registered as no-op Systems to expose static helpers. Godot/Jolt retains physical transform/velocity authority unless an explicit synchronization contract says otherwise.

### Physical motion execution contract

The main-level root schedules `Input → Interaction → Physics → GamePlay`; Godot then invokes the child body callbacks. Dependencies within a group remain declared by `deps()`. Systems prepare intent, control policies and pending impulses; the physical callback consumes them. `MotionRules` provides the shared effective-speed/material-traction calculation and has no scheduled or physical state writer.

| Boundary | Owner and permitted writes |
| --- | --- |
| Raw player events and held/edge snapshot | `S_PlayerInput` writes `C_Controller`; `S_PlayerIntent` derives world motion/look according to control focus. Neither writes physical transform/velocity. |
| Jump, sprint and crouch | `S_Jump` queues an additive `C_Motion.pending_impulse`; `S_Sprint` owns stamina/sprint multiplier from actual body velocity; `S_Crouch` owns posture and collider selection, presentation owns camera/mount height. |
| RigidBody native integration | `E_RigidBodyCharacter._integrate_forces` independently invokes impact capture, optional cart-driver/push contribution, then motion/look. `CharacterMotionSolver` consumes the impulse and samples support through `PhysicsDirectBodyState3D`; `CharacterLookSolver` owns body/head orientation in that callback. |
| CharacterBody native integration | `E_CharacterBodyPlayer._physics_process` invokes native slide motion, walking-push contact contribution, impact capture, then actual support sample in that order. `KinematicCharacterSolver` owns gravity/impulse/transport/step/slide and returns `KinematicMotionSample`, a callback-local immutable-by-contract pair of velocities. That sample is neither persisted state nor another gameplay owner. Independent contact solvers are composed by Entity glue. |
| Native NPC path/avoidance intent | `S_NpcIntent` owns per-frame Controller preparation, waypoint consumption and avoidance request; `E_NpcCharacter.velocity_computed` supplies only a frame-stamped safe-velocity cache. No navigation callback moves the body; expired safe samples are ignored and death clears participation/cache. |
| Route lifecycle and planning | `S_NpcRoute` owns cadence-scoped route clocks/progress/retirement. `S_NpcRoutePlanning` atomically publishes new points and initializes their cursor under its frame budget; `S_NpcIntent` alone advances that cursor between publications. Goals/targets remain in the intent Component and authoritative live Relationships. |

`C_Motion` floor data is a derived physical observation, not transform authority. External jump/damage impulses are additive until the callback consumes them once. Floor adhesion cannot erase upward jump/bounce, moving supports retain relative locomotion, and cart/held cargo keep independent native body callbacks. No artificial solver-forwarding Systems are introduced.

### Service smells and request timing

Review a recurring execution path as a hidden System when it has any of these properties:

- System `process()` mainly forwards to `Service.tick/update/process`, directly or through `cmd.add_custom()`.
- A Service advances `delta`, cooldowns, frame budgets or recurring lifecycle, performs scheduled broad `ECS.world.query` iteration, or orders multiple service steps each frame.
- A frame loop polls a day/phase/state transition that should have a discrete owner/event path.

The remedy is to move scheduled work into its owning System, split differing responsibilities into Systems with `deps()`, or replace transition polling with an Observer/event. Narrow remaining Services to explicit operations and rename misleading classes. Preserve required callback Solvers as bounded engine exceptions. An explicit transaction, read/lookup, spawn command or multi-C/R one-shot operation is not a smell merely because it touches ECS; neither are Rules/Geometry calculations or required physics integration. CommandBuffer is for GECS-safe deferred work, not an architectural escape from scheduled ownership.

Pinned GECS `World.emit_event()` dispatches synchronously. An Observer's default `PER_CALLBACK` buffer executes after its callback; `MANUAL` waits for `World.flush_command_buffers()`. Systems default to `PER_SYSTEM`; `PER_GROUP` buffers execute only after every System in the group. `deps()` orders Systems inside the group and does not make a producer's `PER_GROUP` structural work visible to a later System in that same group. The manual flush method drains MANUAL buffers, not arbitrary pending PER_GROUP work.

Queued Node/Entity owners are captured as `WeakRef` and resolved inside the owning System/Observer callback before typed synchronous operations. A freed Node bound directly to a typed Callable fails before the callback's lifetime guard; pinned GECS structural command lambdas also log a freed-capture error before their internal guard. Project owners therefore use explicit safe callbacks for queued structural removal. Such removal checks the exact captured Relationship is still attached, so GECS pattern matching cannot remove a replacement. Component identity, request generation, calendar/context and participation checks remain required after owner resolution. Disabled terminal owners are validated against World registration rather than the active predicate. A null optional owner and an expired captured runtime owner are different command contexts: the latter must reject/finish its receipt. Resource-only terminal facts retain immutable captured data and validate any live references before use.

`S_Impact` binds its native `body_exited` emitter to a synchronous signal handler; the connection disappears with that same emitter and has no queued World command carrying the body. Physics solvers keep native callback ownership. Neither is a migration-baseline allowance.

Each request boundary declares mutation timing, the flush point, and when a terminal outcome is observable. A successful enqueue/submit may mean accepted/pending; callers must use the committed result/fact for completed behavior. Publish facts only after all fields and structural changes they describe are visible. Synchronous event dispatch permits reentrancy: a recursive command/outcome chain needs a bounded owner and focused test; unbounded feedback is an architecture failure.

The following classifications describe the audited legacy paths and their migration owners, not completed runtime changes:

| Audited symbol | Evidence and destination |
| --- | --- |
| `CustomerOutcomeService.settle` | One explicit idempotent transaction, with a single active/pending-challenge eligibility gate. O_CustomerOutcomes owns committed record/calendar/closure reactions; O_CustomerChallengeOutcome consumes actual terminal facts. Planning/arrival/active phase clocks belong to their explicit S/O owners. |
| `HungerService.tick` | `S_Hunger.process` forwards each actor's timed progression; the Service resolves phase and calls `advance`. Move progression/query responsibility to System in 19; retain explicit food/value operations and pure multiplier rules. |
| `ProjectileService.launch` | Explicit factory snapshots damage/attribution and binds a live source. S_CombatProjectile owns flight/TTL/full-segment ray/retirement; old tick removed in 17. Attack and strike clocks belong to S_NpcCombat/S_PlayerMelee with queued identity/generation and reentrant damage checks. |
| `NpcBrainService.tick` | `S_NpcDecision.process` defers perception cadence, actor iteration, trait/role/tree/route orchestration and noise decay. Split these scheduling responsibilities in 15/16, preserving native LimboAI local execution. |
| `CharacterMotionSolver.integrate_forces` | Uses `PhysicsDirectBodyState3D` from `E_RigidBodyCharacter._integrate_forces`. Keep engine callback ownership and independent physical contributions (22); do not move it into a System/helper System. |
| `WalletService.submit` | Synchronously validates/applies one `MoneyOperation` through `apply`; returns COMMITTED/DUPLICATE or rejection status. COMMITTED follows balance/history mutation; DUPLICATE introduces no new effect. Keep transaction boundary (24). |
| `DamageRequestService.submit` | Copies and emits a targeted request; `true` means dispatched, not applied damage. `O_Damage` queues resolution and publishes `DamageResult` after HP mutation or rejection. Default PER_CALLBACK normally resolves during dispatch, but completion is defined by result, not boolean. Preserve request boundary (17/40). |

Challenge lifecycle clocks belong to S_ChallengeRuntime; autonomous floor setup reacts to committed ChallengeActivated, and S_FloorHazard owns periodic damage. Explicit session commands and Geometry measurements retain separate ownership (18).

Static validation catches only dependable lexical patterns. Cadence, indirect helper calls, transition polling, write authority, event reentrancy and result timing remain mandatory review/behavioral-test responsibilities.

### Scene-first authoring

Placed NPCs/objects remain real visible physical/visual scenes in Godot Editor. Templates/Traits compose gameplay capabilities without replacing those scenes with invisible placeholders. Scene-only declarative composition is valid; an empty Template asset is not mandatory. Placed and runtime-spawned Entities have the same C/R runtime contract after materialization; Systems do not branch on authoring origin.

Project-owned Inspector tooling lives under `content/editor/` and is installed explicitly per editor session without changing third-party addons. It captures current authored Resources into a disposable native snapshot, preserves external Script/scene references, and calls the existing composition compiler in a detached headless process. Preview never registers an Entity, runs gameplay or repairs live inputs. Stable level/instance IDs are read-only in this Inspector and change only through explicit undoable authoring commands. See [Entity authoring workflow](../docs/entity_authoring.md).

Permanent level layout, interactive prefab composition, stable HUD/menu hierarchy and reusable actors belong in editable native `.tscn` scenes. Authored configuration/Profiles/Definitions use typed Inspector-editable `.tres` Resources. Scripted `Node.new()` or procedural creation is justified for dynamic objects, effects and genuinely computed geometry; it must not replace an authored scene merely to reduce task time. The existing `settings_menu.gd` builds a legacy static UI in code and is **not** a reference implementation for new menus. Its dynamic rows are permissible. A tooling/editor import pipeline may generate reviewable native assets; runtime may not write project `.gd` source or authored `.tscn` files.

Architectural acceptance is about ownership and clear APIs, not arbitrary size: a cohesive large System stays a System. The local incremental gate `utils/validate_agent_changes.py` flags script-built permanent UI, generator patterns and expanding monoliths for human review, alongside existing strict GECS/domain validators. Do not confuse static PASS with a completed architectural review.

## Vertical domain target

Refactoring v2 migrates project-owned gameplay code from horizontal role roots toward `content/domains/<domain>/<role>/`, with genuine cross-domain infrastructure under `content/shared/<role>/`. Canonical role-folder spelling is enforced by `python utils/validate_domain_structure.py`; final architecture acceptance requires `--strict`, which rejects legacy horizontal gameplay roots.

Domains communicate through typed commands/events, stable public domain APIs, or explicit shared contracts. File moves alone are not a domain migration: ownership and dependencies must move with them.

Execution-model cleanup precedes domain moves. Public data/query access does not grant write authority; declare the owner and permitted operation at each boundary. Shared infrastructure requires real consumers and does not become a universal gameplay Service. The proposal owns the detailed owner/dependency map.

## Migration completion

A declared migration scope is DONE only when all callers, state ownership and execution paths in that scope use the target model. Permanent old/new execution paths, compatibility wrappers kept solely for old callers, duplicate authority, renamed-but-unmigrated classes, partially moved owners and indefinite violation allowlists prevent completion. Temporary adapters exist only inside an unfinished milestone and are removed before DONE unless an explicit external compatibility contract requires them. Later planned scopes may still contain legacy code; this does not permit legacy paths inside the scope being closed.

## Input and interaction

- `S_PlayerInput` captures raw input into `C_Controller`.
- `S_PlayerIntent` converts controller input into gameplay-space motion/look according to current control focus.
- Targeting and presentation are separate: `S_InteractionTargeting` writes `C_Interactor.target/physics_target`; `S_InteractionHighlight` renders highlight from that state.
- `InteractionControlFocus` is the control-priority authority. Current priority order is MODAL > TRANSPORT/PUSH/CARRY as defined by the service > HANDS; drawing reserves its documented capture priority.
- Contextual actions route through `InteractionActionResolver`; do not add parallel raw E/F/LMB/RMB consumers for ordinary item interactions.
- Stable interaction contracts and control mapping live in `docs/physical_grab.md` and `docs/controls.md`.
- Smart Object occupancy is `actor --R_SmartObjectReservation--> object`, with stable authored
  slot/operation IDs. `O_SmartObject` commits typed requests through one synchronous transaction,
  rechecking eligibility/exclusivity after queueing. Markers are presentation and definitions
  are immutable data; there is no second occupancy registry. Exact token/binding retirement
  and accepted restore invalidation are documented in [Smart Objects](../docs/smart_objects.md).

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
- Shared C_ActorIdentityReference reads existing Package/NPC/persistent Component fields without copying IDs; ActorIdentityRules chooses their preserved canonical actor/diagnostic priorities. BoundaryTrace records and reads diagnostics without importing domain identity implementations.
- Runtime Entity references are not durable save identity.
- Current schema-2 snapshot/restore is implemented; durable links use explicit endpoint keys, never serialized live Objects. Its legacy authored `scene/<relative path>` fallback is a known current contract, not the stable-ID target.
- Refactoring v2 preflight target replaces path-derived identity with explicit authored IDs and versions changed formats. The owner explicitly excludes old-save conversion/backward compatibility for this early project; new-format identity/roundtrip/link reconstruction still require validation. Detailed current runtime semantics remain in `docs/persistence.md` until implementation changes them.
- Phase 1 [identity/persistence contract](../docs/persistence.md#refactoring-v2-identity-contract) owns namespace, schema/change, snapshot/restore and save-visible path rules. Task 25 removes path matching before moves; Phase 1 fixtures prove the current format, not the future startup/composition pipeline.

## Validation routing

Use the narrowest relevant surface:
- repository structure: `python utils/validate_project_structure.py`;
- lexical execution guard: `python utils/validate_architecture.py` (symbol/count baseline under `utils/architecture_baseline.json`; trim entries with each migration, empty at 26/27);
- final execution gate: `python utils/validate_architecture.py --strict`;
- save-visible identity/path baseline: `python utils/validate_persistence_baseline.py`;
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

## Game time and decision seeds

The Time domain owns one durable GameClock aggregate inside C_DayCycle. S_GameTime alone advances
microsecond ticks/remainder; calendar transitions retain their existing player-driven authority.
NPC cadence consumes the session timestamp and persists active interval/sample ticks in NpcRecord;
C_NpcDecision holds only the captured transient native interval. Physics frames/deltas remain native
contracts. Pure DecisionRandomRules uses versioned UTF-8 length framing/SHA-256 and the pinned Godot
RNG; sequences advance only at domain commits. See [the time/seed contract](../docs/game_time.md).
