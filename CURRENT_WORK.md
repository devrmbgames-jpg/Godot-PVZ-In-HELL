# Current Work

- State: R06.1 active on master; resumed after user refactor at 93acc61.
- Accepted migration/ordered milestones: WORK.md; exact specification: docs/roadmap/06_1_interaction_hands_carry_push.md.
- Ownership remains relationship-based; body integration owns physics; authored ArmRSlot/ArmLSlot transforms preserved. addons/gecs was dirty before work and is excluded.
- Completed: Inspector-first migration; three-slot ownership and atomic replacement API, allowed hand mask, per-item rotation data. S_Grab.held_in_slot is slot query; held_object is aggregate compatibility query only. Carry load applies only to Carry. Ray excludes all owned objects.
- Refactor reconciliation complete: preserve services/contracts and categorized entities; fixed six stale resource references, removed missing COGITO POT inputs, completed DEF_ action class names/direct references. Canonical routes are in PROJECT_INDEX.md.
- Capture/input implementation and unique-token fixes were included in user commits; do not reimplement. New physics regression `test_hand_grip_survives_lowered_anchor_and_restore_grace` still fails and is the next capture-stage investigation.
- Numbering correction complete: positive integer base, smallest free active number, explicit release_number after DELIVERED; no day reset. Terminal includes all active days and last departure. User's number-only scanner feedback preserved.
- Validation: structure, formatter/structure, diff check PASS; receiving_scan_smoke PASS with --quit-after 360 (stable numbers and reuse). Last grab run 49/50; only lowered-hand physics test fails.
- Next: fix the lowered-hand physics fixture/regression in tests/gut/test_s_grab.gd; complete capture/input milestone before implementing Push.
