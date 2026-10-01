# Environment interactables (R13)

Door, Window and Drawer use `C_Openable`, `DEF_OpenableMotion` and the shared `DEF_OpenableAction` set. `requested_open` records the requested endpoint; `actual_fraction` is measured from the physical body. Locks and access requirements keep the R11.1 contract. E opens or closes; when closure is blocked or still moving, Open has priority so E can reverse it. A locked object exposes Unlock only when its authored access requirement can be fulfilled.

`E_Openable` is thin scene glue. `OpenableJointSolver` reads body progress and requests bounded hinge/linear motor velocity and force. It never writes a physical transform or velocity. These prefabs bind the fixed frame as joint A and moving leaf as B. Door and Window have opposite authored hinge directions; Drawer locks all rotation and transverse translation and permits 0.6 metres of travel. Collision blockers prevent closure; removing them allows the servo to finish. Storage can later reuse R11.1 physical slots without creating another inventory owner.

The main scene retains the existing Door node paths. Its left frame beam has clearance for the open leaf. The front Window fits the existing wall opening and opens outside, away from the Terminal. The Drawer includes a fixed cabinet. Child body colliders resolve to the owning Entity through the existing targeting service, and the common highlight/prompt systems handle all four props.

`C_LightCircuit` owns an authored circuit ID, enabled state and light-group IDs. `LightCircuitService` supplies toggle/set/query commands; `S_LightCircuit` synchronizes grouped Light3D visibility, including restored state and late lights. The warehouse switch controls the three `warehouse_lights` OmniLights and leaves outdoor light independent. Future challenges query the circuit state with `LightCircuitService.is_enabled()`.

Level teardown removes live Entities before `World.purge(false)` clears GECS archetype transition cycles. It rechecks the current Entity list after each removal because removing a parent can invalidate children. This supports both explicit scene disposal and engine shutdown.

Validation: `test_light_circuit`, `test_openable_access` and `test_grab_main_scene`; `environment_interactables` checks real joint endpoints, blockers and drawer impulse limits; `environment_interaction` checks real main-scene targeting, action captions/prompts, physical endpoints and light groups. Owner walkthrough remains responsible for visual readability and game feel.
