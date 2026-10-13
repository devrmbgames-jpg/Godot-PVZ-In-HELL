# R27 — согласованный authored district в home-night регрессии

Status: **IN_PROGRESS**

Found while validating [visit commitment](r27_service_visit_commitment.md);
independent fixture owner, linked by [R27](r27_qa_followup.md).

## Task state

### Goal / acceptance

Fix test_delivery_completion._night_session without changing production snapshot validation.
Use the same authored DEF_District as its inherited population fixture; no profile/variation reroll.
Native night/save/retry/restore and payment/failed-promise cases must pass; preserve user save slots.

### Current / evidence

Source `d0568a32b4f80ab02a9ab8ab0d84babe341a91be` has the hard-coded production DEF
in the otherwise legacy test fixture. R27 native completion batch065829445 FAIL28/31.
Isolated `.artifacts/r27_home_night_fixture_probe.stdout.log` FAIL1/1,19/23assertions:
12 profile mismatches,0 active customer roles. DistrictSnapshotRules rejects mismatched profiles;
changed interruption/route policy is not involved in this reproduction.
Main owns test_delivery_completion.gd fixture fix only. The helper now loads the inherited
authored definition and asserts roster membership; production snapshot rules remain unchanged.

### Validation

PASS: native completion31/359assertions (`gut-20261013-071042400`), parser and formatter.
Exact-SHA review NOT_RUN until the owning coherent milestone is committed.

### Owner QA / blockers

No subjective fixture acceptance required. Immutable-SHA review remains required before archive.

### Next

Collect exact-SHA review with the owning milestone, then archive this independent fixture repair.
