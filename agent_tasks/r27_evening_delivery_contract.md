# R27.4 — ожидание частной доставки вечером и срок terminal offer

Status: **PLANNED**

Parent: [R27](r27_qa_followup.md).

## Task state

### Goal / acceptance

- NPC with player-accepted private delivery waits by its own entrance in the evening.
- Both personal NPC offer and terminal acceptance create the same durable obligation.
- It does not keep unrelated city wandering and then cross the district only after a knock.
- Terminal "deliver parcel" is available only before the day of planned personal collection.
- On collection day the offer is absent and acceptance is rejected by gameplay authority too.
- Existing home success/refusal/failed promise, one-time bonus, replay and snapshot contracts remain.
- Native regression covers both acceptance paths, phase placement, boundary days and restore.

### Current

Source `d0568a32b4f80ab02a9ab8ab0d84babe341a91be`;
NpcHomeDeliveryService/HomeDeliveryQueries own obligations, NPC schedule owns evening goal,
TerminalDeliveryInfo/action rules expose delivery availability. Inspect exact owners before edits.
Implementation/testing/review NOT_RUN.

### Validation

NOT_RUN for the changed contract; existing completion tests are baseline evidence only.

### Owner QA / blockers

Owner gameplay acceptance of evening waiting and terminal timing remains open.

### Next

Trace home offer acceptance/evening phase and terminal eligibility rule; fix shared authority first.
