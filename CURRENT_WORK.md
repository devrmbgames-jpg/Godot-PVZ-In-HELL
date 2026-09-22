# Current Work

- State: R06.1 active on master, base ff2db865612e43c69742ca61bd91eb980e148342.
- Accepted migration/ordered milestones: WORK.md; exact specification: docs/roadmap/06_1_interaction_hands_carry_push.md.
- Ownership remains relationship-based; body integration owns physics; authored ArmRSlot/ArmLSlot transforms preserved. addons/gecs was dirty before work and is excluded.
- Completed: Inspector-first migration; three-slot ownership and atomic replacement API, allowed hand mask, per-item rotation data. S_Grab.held_in_slot is slot query; held_object is aggregate compatibility query only. Carry load applies only to Carry. Ray excludes all owned objects.
- Changed: interaction components/S_Grab/targeting, Scanner/Bucket policies, six added tests in test_s_grab.gd.
- Validation: 36/36 grab tests, 147 assertions; formatter/structure and diff check PASS. Earlier receiving scan fixture ray miss and stale main-scene entity count remain for regression stage.
- Next: add shared capture tokens/lowered anchors and replace InteractionActions input routing with state-aware E/F, mapped hands, G and Terminal capture.
