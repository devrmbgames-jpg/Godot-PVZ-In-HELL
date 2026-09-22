# Current Work

- State: R06.1 active on master, base ff2db865612e43c69742ca61bd91eb980e148342.
- Accepted migration/ordered milestones: WORK.md; exact specification: docs/roadmap/06_1_interaction_hands_carry_push.md.
- Ownership remains relationship-based; body integration owns physics; authored ArmRSlot/ArmLSlot transforms preserved. addons/gecs was dirty before work and is excluded.
- Completed: six define_components owners migrated to scenes; only Package identity remains runtime. S_Receiving preserves static components and clones per-parcel grab tuning. Mutable scene state uses resource_local_to_scene.
- Changed: affected entity scripts/scenes, main_level.tscn, s_receiving.gd.
- Validation: formatter/structure, diff check and day_cycle smoke PASS; baseline grab 30/30 PASS. Receiving smoke creates 8 parcels but initial scan ray misses target; main-scene test expects stale count 15 versus existing 16. Track fixture fixes in regression stage.
- Next: implement C_HeldBy.slot, independent cache/slot validation and rotation policy in S_Grab before input changes.
