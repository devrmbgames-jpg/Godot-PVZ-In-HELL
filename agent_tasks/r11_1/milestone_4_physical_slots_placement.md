# R11.1 — Physical slots and Carry placement / milestone 4

Status: **DONE**

Owner task: [R11.1](../roadmap_11_1_extended_interactions_and_arrangement.md)

## Implementation and decisions

- Physical storage is world-Entity storage, not a fourth hand slot and not virtual Inventory. `R_StoredIn` is the live ownership authority; each `E_PhysicalSlot` accepts at most one concrete item.
- `PhysicalSlotService` validates actor reach/focus, occupancy, authored access filter and maximum mass before storage. Stored bodies are attached to the authored slot anchor with simulation/collisions suspended. `StoredBodySnapshot` restores the changed body settings when storage ends.
- Slot lifecycle is reactive through `O_PhysicalSlotLifecycle`: explicit take, relationship removal, slot/component removal, wearer removal and tree teardown all release ownership and restore the body. `R_SlotMountedOn` distinguishes worn/body slots from world shelf slots.
- Transfers reuse the existing hand mapping and `GrabService` ownership path. E/F resolve to the configured physical hands (including swapped controls); occupied-hand replacement is allowed only through the common replacement contract.
- `DEF_WornItemAccess` exposes concrete items stored in slots mounted on the actor, so access requirements can consume/use worn items without introducing virtual inventory ownership.
- Carry placement uses `C_PlacementArea` + `DEF_CarryPlacementAction`. It checks the authored destination volume plus the carried body's real collision shapes and swept path. Rotating moves use a conservative swept bound so a large body is not teleported through an obstacle during rotation.
- Failed placement leaves the object in Carry. Successful placement releases Carry once, aligns the body to the authored transform, and does **not** create storage ownership or freeze the body. Area occupancy is therefore determined by physical presence and becomes free again when the placed object moves away.
- Review finding **M4-R1**: the two authored player belt slots were children of `HeadY`, so they orbited with independent head yaw rather than remaining body-mounted. They now parent directly to the player body while preserving their authored world-relative position. A regression test covers this scene contract.

## Review and validation

- Initial focused GUT on the implementation: **9/9 PASS, 55 assertions**.
- Initial `physical_slots_placement` headless smoke: **PASS**. It covers endpoint obstruction, swept mid-path obstruction, rotated-path obstruction, Carry preservation on failure, successful non-frozen placement and physical occupancy/freeing of the placement area.
- After M4-R1, final focused GUT: **10/10 PASS, 60 assertions**; the new case verifies both player belt slots are children of the body root.
- Final `physical_slots_placement` headless smoke: **PASS**.
- Project structure/naming validation: **PASS**.
- Validation ran on Godot **4.7.1 stable** with the repository-pinned GECS submodule. The standalone editor-import step still prints unrelated read-only addon diagnostics: GECS `system.gd:418` cannot infer `measure_time`, Dialogue Manager reports theme-init Nil assignments, and the import process reports exit leaks. The step exits successfully, but it is intentionally **not** claimed as a clean whole-project import. Focused M4 GUT and smoke themselves completed successfully.
- Temporary validation workflow was removed after the final run.
- No rendered/visual Godot run was performed. Owner QA is still appropriate for the exact belt-slot visibility/reach and placement-area authoring/feel; it is not a blocker for the generic M4 contracts.

Validation runs: GitHub Actions `36451895022` (initial) and `36452331613` (final).
