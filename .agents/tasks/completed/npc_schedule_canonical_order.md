# Canonical NPC schedule choice ordering
Status: **DONE**

Parent/dependency: [R26.3](r26_3_npc_behavior_trees.md).

## Task state

### Goal

Fix the independently reproduced schedule determinism defect without changing damage,
survival acceptance, authored place IDs or persisted decision sequences. Keyed schedule
choices must use canonical ID text order regardless of StringName allocation/load order.
Require focused native regression, parser/static gates, immutable review and unchanged
full district week. R26.3 owns integration; required owner gameplay QA remains a separate gate.

### Current

Final linked production week `tests/artifacts/district-20261013-112524520.log` **PASS**, wrapper exit0: all seven days,
unchanged survival requirement >=6/8 original residents, night/snapshot/restore/navigation/identity pass.
Code checkpoint `4c60e3dc784352c2fb95ca617cebbafa9a834366`; exact floor-pressure review
BASE `f9888f3c87fb7715d5ab8bdf07b5ef55382c5979` -> TARGET `4c60e3dc784352c2fb95ca617cebbafa9a834366` PASS, no findings.
Wide floor tuning1HP/0.5s is owned by R26.5; radius10m/TTL60s and torso aura4HP unchanged.
Scoped repair code/reviews remain valid ancestors; prior failed weeks below are historical evidence.
No accepted findings or required automated gates remain open in this scoped task.
Rendered gameplay/visual and final balance QA NOT_RUN; these remain in the original R26 tasks.

BASE `f8e5ea5c0d6935c1187232826cbd53efd0f4a411` ->
TARGET `c21ac06cc4e71d339e47c2dbe7e3b737fe82d49c`.
`NpcScheduleRules.goal_for` now compares `String(first) < String(second)` explicitly.
No schema or durable record changes; already committed goals retain their authored IDs.
Immutable review **PASS**, same reviewer, no findings (24s).
Architecture/style PASS; reviewer runtime NOT_RUN. Historical week082044400 FAIL5/required6;
independent low-health escape rejection is reproduced in [its task](npc_hazard_escape_low_health.md).

### Review triage

RV-001 P1, source `f8e5ea5c0d6935c1187232826cbd53efd0f4a411`,
`content/domains/npc/rules/npc_schedule_rules.gd::goal_for`: **FIXED**
`c21ac06cc4e71d339e47c2dbe7e3b737fe82d49c`, GUT12/167 and immutable review PASS.
`Array[StringName].sort()` orders interned addresses in pinned Godot 4.7.1.
At equal first-tick clock16666, actor-script-only ablation changes candidate order while
RNG seed/index stay equal: original `[activity_1, activity_0, activity_3, activity_2]`,
material-filter actor `[activity_1, activity_0, activity_2, activity_3]`.
Thus npc/2, npc/4 and npc/7 receive different initial goals before physical positions diverge.
This disproves the earlier actor-reset hypothesis. The repaired order alone does not resolve survival.

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
Affected native schedule/route acceptance GUT222506041 **PASS41/260**.
Full unchanged week `tests/artifacts/district-20261013-082044400.log` **FAIL5/required6**.

### Next

Scoped task completed and archived. Continue only the original R26 owner-QA gates.

### Owner QA / blockers

Scoped implementation, native verification, immutable reviews and final linked district week PASS.
No scoped blocker remains. Required R26 gameplay/visual acceptance and final floor balance
remain [owner QA](../../../.qa/tasks/r26_acceptance.md); no rendered QA is claimed.
