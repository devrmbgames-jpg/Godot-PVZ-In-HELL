# R27.1 — план визита сохраняется до вызова к стойке

Status: **IN_PROGRESS**

Parent: [R27](r27_qa_followup.md).

## Task state

### Goal / acceptance

- NPC avoidance/emergency while waiting does not cancel the planned same-day visit.
- A blocked approach can defer a living recipient only after its queue turn is called.
- Queued wandering/temporary interruptions preserve unresolved order and day-shift blockers.
- Preserve native light-warning/timeout, death/outcome cleanup, inspection and home-role contracts.
- Native regression must retain six planned visits through avoidance and prove the front-only route gate.

### Current

Source `d0568a32b4f80ab02a9ab8ab0d84babe341a91be`:
NpcServiceRole.enqueue_next defers a not-yet-started visit for fear/combat;
CustomerRoleInterruptionService.suspend releases/defer-closes any unresolved counter visit;
O_CustomerNpcInterruption ROUTE_BLOCKED does not distinguish queued wandering from called approach.
These match owner QA: six scheduled recipients become only two actual visitors.
Implemented: preparation pauses without deferral; temporary interruptions release execution while
retaining unresolved counter plans. ROUTE_BLOCKED defers only a SERVICE-owned APPROACHING role
with its live counter binding. Main owns customer role/interruption and focused regressions.

### Validation / review

PASS: native visit commitment55/443assertions (`gut-20261013-065655235`);
native completion31/359 (`gut-20261013-071042400`), including home interruption contracts.
PASS: changed parser, formatter, strict architecture and persistence inventory.
PASS: companion MCP path-bound diagnostics for three gameplay scripts, checked/error_code0.
Native script_patch anonymous-source preliminary check returned43; path-bound compilation is clean.
PASS: district_release write `district_release-write-20261013-171346097.log` and fresh restore
`district_release-restore-20261013-172405454.log`, native exit0. Shutdown retention DEFERRED.
Checkpoint `4a287e181a9d03ecc00105cb7a6edc1d6cae93ab`, base
`d0568a32b4f80ab02a9ab8ab0d84babe341a91be`, reviewed read-only in246seconds.
ARCHITECTURE FAIL for RV-001; STYLE PASS; reviewer validation NOT_RUN.
Repair: home completion is restricted to DELIVERED/CUSTOMER_REFUSED; counter terminal cleanup
retains the broader condition. Native completion32/375 PASS (`gut-20261013-073035059`),
parser2 PASS and companion MCP checked/error_code0. Targeted re-review pending repair commit.

Canonical RV-001 (reviewer R1, P1), source `4a287e181a9d03ecc00105cb7a6edc1d6cae93ab`:
CustomerRoleInterruptionService.suspend returned early for home PLAYER_DENIED although
NpcHomeDeliveryService.complete rejects that actual. ACCEPTED; implemented cleanup repair,
native denied-home emergency test verifies role/meeting/inspection release and no invented payment.

### Owner QA / blockers

Owner gameplay acceptance remains open; no rendered playtest was run by the agent.

### Next

Commit RV-001 repair and collect targeted re-review; continue independent R27 scopes.
