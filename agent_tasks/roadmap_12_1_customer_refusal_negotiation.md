# R12.1 - Customer refusal negotiation and repeat visits

Status: **OWNER_QA**

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
- [x] Focused regression validation and docs.
- [x] Independent review; move to OWNER_QA.

### Decisions
- A response tag identifies intent only. It never directly encodes rage, complaint percentages or other balance values.
- Joke intent never commits denial.
- Dialogue/physical interaction owns actual; Terminal owns declaration.
- A finished physical visit may leave the package case unresolved. If no complaint is created, deterministic follow-up scheduling may reactivate the same case on a later day.
- On follow-up reactivation, current actual resets to NOT_RESOLVED so the package can still be delivered; player_denial_count preserves prior factual denials.

### Current
Technical implementation and review are complete on master. Next: owner gameplay/visual QA only.

### Validation
- Project validation PASS on final implementation SHA.
- R12.1 negotiation validation PASS: target GDScript parser checks, CustomerFlowService parser copy, DialogueManager source compile, and static authority invariants.
- Validation runs: 36571644697 (Project validation) and 36571644653 (R12.1 negotiation validation).

### Owner QA / blockers
Gameplay/visual QA required:
- Talk to a waiting Customer and choose refusal branches for honest/lie/persuade/threat/flirt/joke.
- Confirm joke returns to a non-denied path; other refusal outcomes can leave or become aggressive according to policy.
- Deliver a Package but declare REFUSED or LOST in Terminal; actual must remain DELIVERED.
- Refuse/withhold a Package but declare TAKEN in Terminal; actual must remain PLAYER_DENIED/NOT_RESOLVED as appropriate.
- Leave declaration NONE and advance days until at least one repeat visit occurs; confirm the Customer asks about the same registered Package again.
- After a repeat visit, confirm the Package can still be delivered and prior player_denial_count/history is preserved.
No technical blocker is currently recorded.
