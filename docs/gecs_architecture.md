# Gameplay scheduling and physics boundaries

Pinned local GECS v8 is the API authority. Components contain data; live bindings use Relationships; Systems schedule one responsibility. Typed requests/results and state connect owners. Services/solvers are not registered as Systems.

The main scene processes `Input → Interaction → Physics → GamePlay`; `deps()` orders work within a group. Raw capture and player intent are separate. Body callbacks read the resulting intent/state; Systems never call one another as services.

`E_RigidBodyCharacter._integrate_forces()` captures impacts, then chooses transport follow, push follow, or regular motion/look. This Entity is the orchestration boundary; Motion/Look/Push/Cart solvers are independent `RefCounted` helpers and retain Jolt body authority. `E_TransportCart._physics_process()` owns CharacterBody cart stepping; cargo callbacks own velocity restraint. Authored held bodies use their body callback; generic rigid bodies have the documented pre-physics force/velocity fallback. There are no registered no-op Motion/Look/Cart helper Systems.

`S_Crouch` owns crouch state and collision-shape transitions. The preserved legacy name `S_CrouchPresentation` interpolates the shared `camera_root`/HeadRoot geometry after that transition. In the authored character, this root contains the interaction ray and hold/hand anchors as well as the camera. Its movement is therefore gameplay glue, not an optional camera-only visual effect. Node paths, exported field names and timing remain unchanged. Look head axes and collision/raycast/anchor references stay in the Entity.

Targeting writes `C_Interactor`; highlight reads it and restores overlays through lifecycle cleanup. Marker holder comes from `R_HeldBy`; cursor sampling, ink mutation and mesh rendering have separate owners. Receiving schedules batch transactions, constructs packages through a factory and resolves live package IDs through the registration domain. Day commands are typed requests on `C_DayCycle`. Health arithmetic belongs to the damage observer; lifecycle/presentation consume typed results.

Derived cargo/driver/holder caches remain rebuildable. Durable identity and saved operation IDs do not replace live relationship authority. Structural mutation during scheduled iteration uses CommandBuffer or explicitly safe copied-query/lifecycle paths. Dead/depleted state and actual removal have distinct owners.

R22.5 milestone evidence and remaining audit/validation are recorded in its task and milestone files. Rendered/gameplay acceptance remains in the owning feature tasks and R23.
