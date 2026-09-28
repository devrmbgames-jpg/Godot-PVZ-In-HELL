# R22.5 — GECS Architecture Polish

Status: **DEFERRED**

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
- [ ] M1 — System decomposition.
- [ ] M2 — Interaction/domain boundaries.
- [ ] M3 — Physics solvers and scheduling.
- [ ] M4 — Final architecture audit and bounded validation.

### Decisions
R22.5 is intentionally deferred, not blocked. Root router owns overall status; milestone files are bounded executable units and must be verified against current code when resumed.

### Current
M0 is complete. No implementation is active. When dependencies are ready, resume with M1 and first rebuild the current system/dependency disposition before editing.

### Validation
M0 validation is recorded in its milestone file. No later-milestone validation has run.

### Owner QA / blockers
Dependency gate: broader feature work R08–R22 must be stable before resuming architecture polish.

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
| M1 System decomposition | planned | [m1_system_decomposition.md](r22_5/m1_system_decomposition.md) |
| M2 Interaction/domain boundaries | planned | [m2_interaction_domain.md](r22_5/m2_interaction_domain.md) |
| M3 Physics solver classification | planned | [m3_physics_solvers.md](r22_5/m3_physics_solvers.md) |
| M4 Final audit/validation | planned | [m4_final_audit_validation.md](r22_5/m4_final_audit_validation.md) |

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
