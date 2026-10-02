# R22.5 M2 — Interaction and Domain Boundaries

Status: **DONE**
Owner task: [R22.5](../roadmap_22_5_gecs_architecture_polish.md)

## Task state

### Goal
Separate authoritative interaction/domain state transitions from presentation and construction helpers.

### Current
Current owners audited. Targeting/highlight, marker session/surface/ink/view and receiving/day request boundaries already separate. Highlight cleanup hardened; receiving identity lookup now uses `PackageRegistrationService.find_live_package()` while preserving `ReceivingPackageFactory.exists()` callers. Next: M3 callback/scheduling and gameplay-critical head geometry audit.

### Validation
Static direct-owner/diff review PASS. No foreign System calls in inspected paths. Two focused highlight regressions authored for final M4 run (not executed at this milestone). Existing receiving/main fixture is the lookup regression surface. No GUT/engine run for M2, per task runtime budget.

### Owner QA / blockers
No implementation blocker. Rendered gameplay QA remains in owning feature tasks.

## Decisions / review findings

- Target authority stays in `S_InteractionTargeting` / `C_Interactor`; presentation never gates target validity.
- Marker holder is derived from `R_HeldBy`; `MarkerSessionService`, `MarkerSurfaceSampler`, `PackageMarkService` and `PackageMarksView` retain separate ownership. `C_Marker.parcel/stroke` remain transient stroke continuity, not a holder/session binding.
- Receiving batch state/transaction and package construction remain separate; the domain identity query moved to the existing registration service without changing query enabled-state semantics or ID matching.
- Day consumers use `DayPhaseService` and typed `DayTransitionRequest`, not a System instance.
- **R1 FIXED:** highlight overlays/caches previously survived holder removal, loss of `C_Interactor` or System removal. Weak mesh tracking now restores prior overlays and prunes freed meshes; shared targets stay highlighted until the final holder releases. Base System exit cleanup is preserved; targeting state is untouched.
- **R2 FIXED:** receiving factory contained its own live package identity scan. Existing public factory API now delegates to the domain registration lookup. No new cache/identity authority.
- Authored tests cover presentation teardown without target mutation and shared target cleanup through real World/entity/component lifecycle. Final execution belongs to M4.

---

## Goal

Separate authoritative state transitions from presentation and construction helpers.

## Targeting / highlight

Current target shape:
- `S_InteractionTargeting` writes authoritative `C_Interactor.target` / `physics_target`;
- `S_InteractionHighlight` is presentation-only;
- `InteractionTargetingService` owns raycast/collider resolution helpers.

Preserve this separation. Highlight must never participate in target validity.

## Marker

Split by authority only when needed:
- marker session/focus lifecycle;
- surface sampling helper;
- package mark mutation;
- presentation.

Holder comes from `R_HeldBy`; do not restore `C_Marker.actor` or invent redundant drawing ownership.

Use typed samples/events if scheduled responsibilities require decoupling.

## Receiving

Desired boundary:
- phase/day reaction arms batch state;
- receiving System processes pending receiving state;
- scene construction/configuration belongs in a package factory/helper;
- package lookup uses established domain identity/registration services instead of ad-hoc broad queries;
- world structural changes use the pinned GECS-safe lifecycle.

Do not call the DayPhase System as a service.

## Day phase

Keep scheduled phase transition processing over `C_DayCycle`.

Pure predicates/queries may live in a non-System helper/service. Commands arrive through typed request/state/event. Consumers observe cycle state/events instead of depending on a System instance API.

## Presentation boundary

Gameplay Systems/Observers produce authoritative state. UI, highlights, camera-only feedback and other presentation consume that state.

Do not move gameplay validation into visual consumers.

## Acceptance

- targeting remains independent of highlighting;
- no foreign System calls in Marker/Receiving/Day consumers;
- scene construction helpers are not disguised Systems;
- typed contracts express cross-subsystem transitions;
- no gameplay behavior redesign.
