# R22.5 M2 — Interaction and Domain Boundaries

Status: **PLANNED**  
Owner task: [R22.5](../roadmap_22_5_gecs_architecture_polish.md)

## Task state

### Goal
Separate authoritative interaction/domain state transitions from presentation and construction helpers.

### Current
Not started. Reconfirm current targeting/highlight/marker/receiving/day-phase boundaries before editing.

### Validation
Not run.

### Owner QA / blockers
Deferred by the R22.5 dependency gate.

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
