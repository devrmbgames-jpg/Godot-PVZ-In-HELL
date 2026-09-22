# Current Work

- State: R06.1 active on master.
- Accepted migration/ordered milestones: WORK.md; exact specification: docs/roadmap/06_1_interaction_hands_carry_push.md.
- Ownership remains relationship-based; body integration owns physics; authored ArmRSlot/ArmLSlot transforms preserved. addons/gecs was dirty before work and is excluded.
- Completed: Inspector-first migration; three-slot ownership and atomic replacement API, allowed hand mask, per-item rotation data. S_Grab.held_in_slot is slot query; held_object is aggregate compatibility query only. Carry load applies only to Carry. Ray excludes all owned objects.
- Changed: interaction components/S_Grab/targeting, Scanner/Bucket policies, six added tests in test_s_grab.gd.
- Validation: 36/36 grab tests, 147 assertions; formatter/structure and diff check PASS. Earlier receiving scan fixture ray miss and stale main-scene entity count remain for regression stage.
- URGENT correction before next R06.1 milestone: current R06 registration numbering must be changed from `DDD-NNN`/per-cycle sequencing to reusable base numbers displayed as `№001`, `№002`, ... . Allocate the smallest free positive number across active packages; retain it across days; free/reuse only after the package leaves warehouse lifecycle; suffix metadata must not affect allocation. Source: ТЗ 05.
- Next after correction: add shared capture tokens/lowered anchors and continue InteractionActionResolver input routing with state-aware E/F, mapped hands, G and Terminal capture.
