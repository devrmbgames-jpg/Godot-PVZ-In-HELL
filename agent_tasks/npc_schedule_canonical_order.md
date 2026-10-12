# Canonical NPC schedule choice ordering
Status: **IN_PROGRESS**

Parent/dependency: [R26.3](r26_3_npc_behavior_trees.md).

## Task state

### Goal

Fix the independently reproduced schedule determinism defect without changing damage,
survival acceptance, authored place IDs or persisted decision sequences. Keyed schedule
choices must use canonical ID text order regardless of StringName allocation/load order.
Require focused native regression, parser/static gates, immutable review and unchanged
full district week. R26.3 integration and owner gameplay QA remain separate open gates.

### Current

BASE `f8e5ea5c0d6935c1187232826cbd53efd0f4a411`; repair checkpoint to be resolved after commit.
`NpcScheduleRules.goal_for` now compares `String(first) < String(second)` explicitly.
No schema or durable record changes; already committed goals retain their authored IDs.
Full district week is running. Review **REVIEW_PENDING** until immutable repair SHA is collected.

### Review triage

RV-001 P1, source `f8e5ea5c0d6935c1187232826cbd53efd0f4a411`,
`content/domains/npc/rules/npc_schedule_rules.gd::goal_for`: **ACCEPTED / repair validated**.
`Array[StringName].sort()` orders interned addresses in pinned Godot 4.7.1.
At equal first-tick clock16666, actor-script-only ablation changes candidate order while
RNG seed/index stay equal: original `[activity_1, activity_0, activity_3, activity_2]`,
material-filter actor `[activity_1, activity_0, activity_2, activity_3]`.
Thus npc/2, npc/4 and npc/7 receive different initial goals before physical positions diverge.
This disproves the earlier actor-reset hypothesis; week survival causality after repair is pending.

### Validation

Isolated logs under `.artifacts/cloud_baseline_588b59c1/tests/artifacts/`, date20261013:
`startup-original-trace-20261013.log` and `startup-filter-trace-20261013.log` compare179
read-only native physical samples; first goal difference at the same clock16666.
`startup-filter-goals-20261013.log` is clean bounded diagnostic (full week NOT_RUN).
Original-goals diagnostic contains an instrumentation-only invalid awareness field access;
do not count that run as runtime PASS. Its pre-error schedule seed/order output is retained.
Native unfixed GUT `.artifacts/godot_agent/gut-20261012-221944532.*.log` FAIL11/12,
150/167 assertions; canonical sequence test demonstrates17 incorrect choices.
Repaired GUT222017084 **PASS12/167**; native parser222019411 **PASS2files**;
scoped GDQuest formatter/lint PASS. Editor hot reload43 NOT_PASS; fresh native parser PASS.

### Next

Collect unchanged full week, commit the coherent fix, reuse the existing reviewer on full SHAs,
triage against current HEAD, then resume R26.3 cross-archetype/roster integration.

### Owner QA / blockers

Required full week and immutable review are pending. No rendered gameplay or visual QA ran.
