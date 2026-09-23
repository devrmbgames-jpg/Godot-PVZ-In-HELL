# Work Tracker

State: active ? R08. Base ed07f56.

- [x] 1: Generic Health and independent lifecycle reactions.
- [x] 1.1: Single-fire depletion effects and typed hooks.
- [ ] 2–5: Generic impact, pair dedup, valid throw bonus and source veto (Milestones 2–4 implemented; finish M5).
- [ ] **5.1 IMMEDIATE GATE:** refactor `S_Damage` + `S_Impact` to atomic GECS boundaries; remove System→System calls and `ECS.world.systems` service locator before any M6 work.
- [ ] 6–9: Package profiles, protection, liquid tilt, intentional opening (blocked by M5.1).
- [ ] 10: Feedback, static review and manual verification instructions.

User owns all runtime/tests; do not launch Godot, GUT or smoke tests. Static structure/formatter/diff checks only. Preserve dirty addons/gecs. Dependencies R02/R04/R05/R06.1 confirmed in task_history.md.
