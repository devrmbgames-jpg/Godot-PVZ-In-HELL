# Current Work

- State: R06.1 active on master; resumed after user refactor at 93acc61.
- Accepted migration/ordered milestones: WORK.md; exact specification: docs/roadmap/06_1_interaction_hands_carry_push.md.
- Ownership remains relationship-based; body integration owns physics; authored ArmRSlot/ArmLSlot transforms preserved. addons/gecs was dirty before work and is excluded.
- Completed: Inspector-first migration; three-slot ownership and atomic replacement API, allowed hand mask, per-item rotation data. S_Grab.held_in_slot is slot query; held_object is aggregate compatibility query only. Carry load applies only to Carry. Ray excludes all owned objects.
- Refactor reconciliation complete: preserve services/contracts and categorized entities; fixed six stale resource references, removed missing COGITO POT inputs, completed DEF_ action class names/direct references. Canonical routes are in PROJECT_INDEX.md.
- Capture/input complete: unique tokens support same-owner nesting, weak owner cleanup, lowered anchors preserve ownership, E/F replacement and mapped use/Alt throw, G short/long. User-committed core retained; corrected invalid physics fixture and extra G in smoke.
- Numbering correction complete: positive integer base, smallest free active number, explicit release_number after DELIVERED; no day reset. Terminal includes all active days and last departure. User's number-only scanner feedback preserved.
- Validation: structure, formatter/structure, diff check PASS; grab 50/50 (209 assertions), interaction hands smoke PASS (including overlapping real Terminal capture), receiving_scan_smoke PASS with --quit-after 360.
- Next: implement separate Push component/relation/system/cart under the refactored canonical paths; preserve physical authority and shared capture priority.
