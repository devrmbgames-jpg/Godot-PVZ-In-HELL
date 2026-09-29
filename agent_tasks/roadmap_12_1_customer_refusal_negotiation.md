# R12.1 - Customer refusal negotiation and repeat visits

Status: **IN_PROGRESS**

## Goal
Add dialogue refusal/stall/deception approaches while keeping CustomerVisit.actual independent from Terminal declaration. Unresolved registered package cases may return as follow-up visits.

## Constraints
- DialogueManager addon stays read-only.
- Short response intent tags: hon, lie, prs, thr, flr, jok.
- Tags select intent only; DEF_Customer reaction data owns gameplay modifiers.
- Terminal declaration never invents the physical/dialogue actual outcome and never forces the NPC to leave.
- MISSED_REGISTRATION remains separate for due packages never registered by the next Morning.
- Repeat visits reuse the persistent CustomerVisit case for this milestone; keep counters/days so a later CustomerCase extraction preserves semantics.
- Deterministic complaint/aggression/follow-up behavior must survive save/load.

## Milestones
- [ ] Typed intents and data-driven customer reactions.
- [ ] Refusal dialogue branch and response-tag forwarding.
- [ ] Separate declaration from actual; bounded dialogue denial transition.
- [ ] Follow-up scheduling and repeat customer visit.
- [ ] Focused regression tests/docs and independent review.
- [ ] Move to OWNER_QA.

## Current
Implementing typed reaction data and persistent follow-up fields on master.

## Validation
Not run yet.

## Owner QA
Required: refusal branches, Terminal lies in both directions, NONE declaration, and at least one repeat visit.
