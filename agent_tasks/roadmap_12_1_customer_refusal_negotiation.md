# R12.1 - Customer refusal negotiation and repeat visits

Status: **IN_PROGRESS**

## Task state

### Goal
Add dialogue refusal/stall/deception approaches while keeping CustomerVisit.actual independent from Terminal declaration. Unresolved registered package cases may return as follow-up visits.

### Constraints / acceptance
- Feature-level tracked task extending completed R11/R12 contracts; do not reopen or rewrite R12 history.
- DialogueManager addon remains read-only; use short response tags: hon, lie, prs, thr, flr, jok.
- Tags select player intent only; DEF_Customer reaction data owns Satisfaction/Complaint/Aggression/follow-up modifiers.
- Terminal declaration never invents the physical/dialogue actual outcome and never forces the NPC to leave.
- MISSED_REGISTRATION remains separate for due packages never registered by the next Morning.
- Repeat visits reuse the same persistent CustomerVisit case in R12.1; keep visit/follow-up counters so later CustomerCase extraction preserves semantics.
- Complaint, aggression and follow-up decisions remain deterministic across save/load.

### Milestones
- [x] Typed intents and data-driven customer reactions.
- [x] Refusal dialogue branch and response-tag forwarding.
- [x] Separate declaration from actual; bounded dialogue denial transition.
- [x] Follow-up scheduling and repeat customer reactivation.
- [ ] Focused regression validation and docs.
- [ ] Independent review; move to OWNER_QA.

### Decisions
- A response tag identifies intent only. It never directly encodes rage, complaint percentages or other balance values.
- Joke intent never commits denial.
- Dialogue/physical interaction owns actual; Terminal owns declaration.
- A finished physical visit may leave the package case unresolved. If no complaint is created, deterministic follow-up scheduling may reactivate the same case on a later day.
- On follow-up reactivation, current actual resets to NOT_RESOLVED so the package can still be delivered; player_denial_count preserves prior factual denials.

### Current
Core implementation is in master through refusal intents, declaration separation, and follow-up reactivation. Next: focused validation, review findings, and documentation.

### Validation
Project structure validation is currently blocked only by this task file metadata shape; gameplay validation has not yet been run for R12.1.

### Owner QA / blockers
Owner gameplay/visual QA remains required for refusal branches, Terminal lies in both directions, NONE declaration, and at least one repeat visit.
