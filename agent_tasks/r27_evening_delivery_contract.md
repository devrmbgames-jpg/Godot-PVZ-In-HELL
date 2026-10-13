# R27.4 — ожидание частной доставки вечером и срок terminal offer

Status: **IN_PROGRESS**

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
MCP implementation in progress: persisted accepted jobs override evening location/goal/completion,
native schedule branch holds the recipient at its entrance. Terminal eligibility ends at collection
day, survives prior nights and rebases accepted obligation to the chosen evening. No schema changes.

### Validation

PASS: native evening contract42/469assertions (`gut-20261013-075032740`),
completion32/375 (`gut-20261013-074144158`), return6/46 (`gut-20261013-075103127`).
Companion MCP diagnostics for seven changed role/schedule/return owners checked/error_code0;
BT leaves and changed tests return checked/empty diagnostics after scaffold completion.
PASS: parser12 (`parsefiles-20261013-074210578`); native additional parser4 exit0
(`parsefiles-20261013-075511175`) with shutdown-only retention causing wrapper FAIL/DEFERRED.
Formatter, strict architecture, project structure and persistence inventory PASS.
Connected write `district_release-write-20261013-175251936.log` native PASS exit0;
fresh-process restore `district_release-restore-20261013-175457006.log` native PASS exit0,
recorded result JSON. Shutdown retention DEFERRED.
Initial integration FAIL demonstrated old same-day terminal fixture inputs and future-plan return
gate. Real parcels now have three future collection inputs before registration; offer count and full
scenario acceptance remain. PackageReturnService uses actual last_visit_day (legacy fallback arrival),
covered by native early-home refusal and late-encounter return tests. No production gate weakened.
Exact-SHA review NOT_RUN until this checkpoint is committed.

### Owner QA / blockers

Owner gameplay acceptance of evening waiting and terminal timing remains open.

### Next

Complete native regressions, parser/static checks and connected integration; commit and review full SHA.
