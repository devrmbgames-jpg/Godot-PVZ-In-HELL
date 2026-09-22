# Current Work

- State: R06.1 active on master; resumed after user refactor at 93acc61.
- Accepted migration/ordered milestones: WORK.md; exact specification: docs/roadmap/06_1_interaction_hands_carry_push.md.
- Ownership remains relationship-based; body integration owns physics; authored ArmRSlot/ArmLSlot transforms preserved. addons/gecs was dirty before work and is excluded.
- Completed: Inspector-first migration; three-slot ownership and atomic replacement API, allowed hand mask, per-item rotation data. S_Grab.held_in_slot is slot query; held_object is aggregate compatibility query only. Carry load applies only to Carry. Ray excludes all owned objects.
- Refactor reconciliation complete: preserve services/contracts and categorized entities; fixed six stale resource references, removed missing COGITO POT inputs, completed DEF_ action class names/direct references. Canonical routes are in PROJECT_INDEX.md.
- Capture/input implementation and unique-token fixes were included in user commits; do not reimplement. New physics regression `test_hand_grip_survives_lowered_anchor_and_restore_grace` still fails and is the next capture-stage investigation.
- Validation: deterministic structure check, Godot import (no script errors), formatter/structure and diff check PASS. Grab 49/50; only the named lowered-hand physics test fails. Receiving smoke expectations still use obsolete string numbers.
- URGENT correction before next R06.1 milestone: current R06 registration numbering must be changed from `DDD-NNN`/per-cycle sequencing to reusable base numbers displayed as `№001`, `№002`, ... . Allocate the smallest free positive number across active packages; retain it across days; free/reuse only after the package leaves warehouse lifecycle; suffix metadata must not affect allocation. Source: ТЗ 05.
- Next after correction: add shared capture tokens/lowered anchors and continue InteractionActionResolver input routing with state-aware E/F, mapped hands, G and Terminal capture.
