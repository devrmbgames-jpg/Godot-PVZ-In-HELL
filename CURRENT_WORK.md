# Current Work

- State: R06.1 active on master; resumed after user refactor at 93acc61.
- Accepted migration/ordered milestones: WORK.md; exact specification: docs/roadmap/06_1_interaction_hands_carry_push.md.
- Ownership remains relationship-based; body integration owns physics; authored ArmRSlot/ArmLSlot transforms preserved. addons/gecs was dirty before work and is excluded.
- Completed: Inspector-first migration; three-slot ownership and atomic replacement API, allowed hand mask, per-item rotation data. S_Grab.held_in_slot is slot query; held_object is aggregate compatibility query only. Carry load applies only to Carry. Ray excludes all owned objects.
- Refactor reconciliation complete: preserve services/contracts and categorized entities; fixed six stale resource references, removed missing COGITO POT inputs, completed DEF_ action class names/direct references. Canonical routes are in PROJECT_INDEX.md.
- Capture/input complete: unique tokens support same-owner nesting, weak owner cleanup, lowered anchors preserve ownership, E/F replacement and mapped use/Alt throw, G short/long. User-committed core retained; corrected invalid physics fixture and extra G in smoke.
- Numbering correction complete: positive integer base, smallest free active number, explicit release_number after DELIVERED; no day reset. Terminal includes all active days and last departure. User's number-only scanner feedback preserved.
- Push complete: C_Pushable/C_PushedBy/C_PushControl, S_Push and O_PushLifecycle; fixed cart velocities and physical player handle-follow, no transform writes, separate focus token. E/S stops; modal input pauses motors. Cart at (2, 0.5, -5.6) is verified clear of authored geometry.
- Changed: new Push files under components/interaction, systems/interaction, observers/interaction, definitions/interaction and entities/props; input/resolver/motion wiring; player/main scenes and existing GUT suites.
- Validation: all GUT 64/64 (302 assertions), structure, formatter/lint (project class-name exception) and diff check PASS. Prior hands and registration smoke PASS; rerun smokes after final integration.
- Next: update docs/controls.md, docs/physical_grab.md, content/CONTEXT.md and PROJECT_INDEX.md to final contracts, run remaining smoke checks, archive R06.1 and return trackers to idle.
