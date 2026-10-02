# R22.5 — GECS Architecture Polish

Status: **DONE**

## Task state

### Goal
Refactor working gameplay toward GECS best practices without changing gameplay design, after the feature layer is stable enough that architecture polish will not race active feature work.

### Constraints / acceptance
- Pinned GECS v8 source is API authority.
- Verify every historical issue against current production code before editing.
- Preserve behavior and physics authority.
- Do not re-plan or redo completed M0 relationship migrations.
- Resume only after feature work R08–R22 is stable enough for the targeted milestone.

### Milestones
- [x] M0 — Relationship authority cleanup.
- [x] M1 — System decomposition (current-production audit; already satisfied).
- [x] M2 — Interaction/domain boundaries.
- [x] M3 — Physics solvers and scheduling.
- [x] M4 — Final architecture audit and bounded validation.

### Decisions
Feature implementation R08–R22 is stable for targeted polish; owner rendered/playability QA remains in the owning tasks. Root router owns overall status; milestone files are bounded executable units and must be verified against current code when resumed.

### Current
M0–M4 complete. Current owners audited; highlight/domain lookup, native hazard-follow relationship/lifecycle/persistence and iterated Hunger state hardened. Shared crouch HeadRoot explicitly classified as gameplay geometry with existing paths/timing preserved. R1–R7 FIXED, independent review rechecked. Contract: `docs/gecs_architecture.md`. Next: R23 complete-day validation.

### Validation
M4 final GUT 151/151 PASS, 921 assertions, no project errors/orphans/resource leaks. Strict hazards and integrated main player_feedback smokes PASS. Static gate: 39 scheduled Systems, 28 reactive Observers, no System helper/locator/frame-machine violations or legacy follow-owner field. Structure/diff PASS; separate reviewer: no unresolved material findings. M1–M3 used static-only validation. Detailed evidence/fixture corrections in M4; rendered/full-day/gamepad/audio QA remains in feature tasks/R23.

### Owner QA / blockers
Feature implementation gate satisfied; owner rendered/full-scenario QA remains separate. No agent implementation blocker.

---

Dependencies: R08, R09, R10, R11, R11.1, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22.
Timing: late-roadmap polish before R23 vertical-slice validation.
Source authority: pinned GECS v8 under `addons/gecs/` plus `.agents/skills/gecs-v8/SKILL.md`.

## Goal

Refactor working gameplay toward GECS best practices without changing gameplay design.

Core invariants:
- Components are data/state only.
- Live Entity-to-Entity ownership/session/binding uses Relationships.
- Systems have one scheduled responsibility and never call another System as a service.
- Hot scheduled work uses narrow queries + `iterate()`.
- Typed state/events/relationships replace System service APIs.
- CommandBuffer/approved lifecycle handles structural mutation during iteration.
- Godot child references stay Entity glue.
- Gameplay authority and presentation stay separate.
- Physics callback orchestration at Entity boundaries is allowed; pseudo-Systems used only as static helpers are not.

Do not perform unrelated R22.5 cleanup opportunistically while implementing another feature unless a blocking defect requires a minimal local fix.

## Progressive-disclosure milestones

Read only the milestone being worked on.

| Milestone | Status | File |
| --- | --- | --- |
| M0 Relationship authority | implemented for Cart cargo/driver, throw attribution and Marker holder; retain audit guard | [m0_relationship_authority.md](r22_5/m0_relationship_authority.md) |
| M1 System decomposition | done: current owners satisfy historical targets | [m1_system_decomposition.md](r22_5/m1_system_decomposition.md) |
| M2 Interaction/domain boundaries | done: cleanup and domain lookup hardened | [m2_interaction_domain.md](r22_5/m2_interaction_domain.md) |
| M3 Physics solver classification | done: callbacks/groups and shared head geometry verified | [m3_physics_solvers.md](r22_5/m3_physics_solvers.md) |
| M4 Final audit/validation | done: 151 tests, strict hazard/main smokes and independent review | [m4_final_audit_validation.md](r22_5/m4_final_audit_validation.md) |

## Current repository facts

Do not re-plan completed M0 migrations:
- cargo authority: `R_CartCargo`; `C_CartTransport.cargo` is documented derived/rebuildable cache;
- cart-driver authority: `R_CartDrivenBy`; `C_CartDriver.cart` is derived/rebuildable cache;
- deliberate throw attribution/lifetime: `R_ThrownBy`; `C_ThrowDamage` contains only authored throw configuration;
- Marker holder derives from `R_HeldBy`; `C_Marker` has no actor field.

Before resuming a later milestone, inspect current production symbols named by that milestone. Do not trust historical “current issue” descriptions without verifying them against `master`.

## Local reference shape

`S_Jump` is the reference for a focused scheduled System:
- narrow responsibility;
- narrow query;
- iterated required components;
- no foreign System calls;
- no unrelated presentation/service API.

Do not refactor a valid System just because it is small, and do not split cohesive physics math merely to reduce line count.

## Runtime budget

Milestone work uses static/deterministic checks only. Reserve the task-level GUT + headless smoke/runtime pass for M4 unless a blocking defect cannot be resolved statically.

Do not launch rendered/visual Godot without explicit user approval.

## Resume rule

When R22.5 is explicitly resumed:
1. read this router;
2. read only the selected milestone file;
3. inspect the exact current production symbols;
4. update `CURRENT_WORK.md` with that milestone and one next step;
5. commit each coherent milestone separately.

Do not read the entire `r22_5/` folder up front.
