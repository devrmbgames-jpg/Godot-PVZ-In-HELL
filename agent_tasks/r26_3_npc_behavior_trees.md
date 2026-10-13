# R26.3 — LimboAI Behavior Trees for NPC archetypes
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Implement the requested NPC behaviors as **real Behavior Trees** using LimboAI v1.8.1.
Follow [limboai-v1.8](../.agents/skills/limboai-v1.8/SKILL.md) and [game-ai](../.agents/skills/game-ai/SKILL.md).
`bt_npc_action.gd` is a narrow lifecycle base; `NpcDecisionService` exposes explicit operations.
Extend visible tree selection; a leaf dispatching an entire decision tree remains prohibited.

### Current

Conditional escape `588b59c1771d95b4ffba278988ddef0a364013a7` adds typed reusable Veil,
native cloud hazard/confirmed-threat flight and optional invisibility after lost sight.
Authored VeilPresence changes appearance only; physical movement/collision/damage remain intact.
Task tokens protect replacement forms; reset, profile, death and participation clean synchronously.
Review **PASS**: BASE `a2b1d764b1b316b27df979a8d72917d6deab8ed8`
-> TARGET `588b59c1771d95b4ffba278988ddef0a364013a7`, same reviewer, no findings (95s).
Architecture/style PASS; reviewer runtime NOT_RUN. Final smoke FAIL survival5/required6;
Comparable BASE week PASS; mortality traces prove floor-fire deaths. Endpoint repair is reviewed,
but final week071658349 still FAIL5/required6; original causal diagnosis remains open.
Reset-call ablation080407835 still FAIL5. First-tick traces prove a separate deterministic
schedule defect: equal seed/index select different StringName candidate orders before movement.
Explicit text-order repair and regression are in [their task](npc_schedule_canonical_order.md);
focused GUT12/167 and parser PASS; unchanged week082044400 still FAIL5. Repair review PASS24s
on `f8e5ea5c0d6935c1187232826cbd53efd0f4a411` -> `c21ac06cc4e71d339e47c2dbe7e3b737fe82d49c`.
Low-health exit rejection FIXED `5670d3566328a3e831921f2a845276de6a981ee1`;
[native89/627 and immutable review PASS24s](npc_hazard_escape_low_health.md). Full week083125987 FAIL5.

### Validation

Cloud batch GUT **136/2406 PASS**, `.artifacts/godot_agent/`, date20261012:
Veil20324494715/127; participation2025201979/162; sight2026361738/27;
native lifecycle20313622251/346; feeding20323005711/95; light20324240812/159;
night20265103420/186; catalog2027054844/944; variation2027088306/360.
Parser20273604220files plus final2032045052files PASS; formatter, strict architecture/domain,
structure, staged index, diff and persistence gates PASS. Final smoke
`tests/artifacts/district-20261013-063246721.log` FAIL, survival5/required6; preceding
062736299 also FAIL before final FLEE fixes. Comparable BASE week PASS:
`.artifacts/cloud_baseline_588b59c1/tests/artifacts/district-20261013-064942431.log`.
Same BASE controls: component072420148, BT073004587, visibility074419873 PASS;
old scene073431612, reverted decision073919530, actor074843088, zero-clock075712248 FAIL5.
All six corresponding native parsers PASS. Reset-call ablation080407835 FAIL5.
Bounded179sample traces (full week NOT_RUN) isolate the first goal difference at equal clock16666;
allocation-dependent schedule ordering is proven; detailed evidence is in the linked task.
Shutdown-only retention KNOWN_ENGINE_LIMITATION/DEFERRED; mandatory/live/owner QA remains open.

### Next

Continue cross-archetype acceptance and all-ten live roster binding with explicit role/save contracts.
Keep unchanged full week survival6 mandatory; do not waive R26.5/owner QA or claim mortality resolved.

### Review triage

Canonical source/fix SHAs below are ancestors of current code HEAD
`78e9b826470dce320bf9999f495ed0c05ab8c8f5`; prior light/feeding/blood/UI reviews added no findings.
Full-SHA audit:26 earlier checkpoints PASS; audited baseline
`5670d3566328a3e831921f2a845276de6a981ee1` and both feedback repairs remain ancestors
of current code HEAD. RV-001..005 retain FIXED; latest [review/gates](r26_5_integration_persistence_validation.md).

RV-006 P1 FLEE_EXIT continuation, Main reproduction/source
`a2b1d764b1b316b27df979a8d72917d6deab8ed8`, NpcDecisionService.flee:
FIXED `588b59c1771d95b4ffba278988ddef0a364013a7`; baseline202020933 freed-actor access.
Veil20324494715/127 and lifecycle20313622251/346 PASS, including native reset/retirement,
normal dormant fear cleanup and direct role-release API. Immutable checkpoint review PASS.

RV-005 P1 camera exposure, source `3e88b56983a775cc78c225353251ff6a98d33b87`:
FIXED `23fa3d44d9024d4becb59477921be1d288d7bee9`, GUT18342894914/111,
parser1834543174/4; baseline183345914 FAIL13/14 retained exposure across suspension.
Sensing reset before runner lookup preserves memory; targeted review PASS.

RV-004 P2 fatal threshold101, source `3a18bbc5275463d05328744e767e923cf8242d7b`:
FIXED `4f956de8db9a62aa8bd13df53c150025798aa1d0`, Soul05352171816/186, parser053544530/2.
Boundaries0/101 preserve ledger;1/100 produce valid offers. Targeted review PASS.

RV-001 P1 hunt publication/update lifetime, source `a963f56e83f29810238739751780e95041847078`:
FIXED `b798cfb4817c6d4e05f01a52a66695a9e82b3c71`, hunt00110132914/125.
Retirement/reset/dormant regressions and targeted immutable review PASS; original evidence in Git.

RV-002 P1 cached native trait preflight, source `eb3b40d44d9da9e36c1b7d69bc9b36e148b74b42`:
FIXED `510a074b4161f65a67d93fb46d4a5f61a2b62b56`, preflight0210376067/56.
Detached disk validation and targeted review PASS; original live-cache reproduction in Git.

RV-003 P1 post-aura publication continuation, source `0daa93c2898a19b28f5c827a4e81b5436b67e9c8`:
FIXED `2fbd959480f0c2ff5f028d7ba012651634ea9fe8`, fire04195606711/77.
Baseline041905500 reproduced freed-body access/writes after dormancy/reset via real System/CommandBuffer.
Repair revalidates world, participation and Component identity; live continuation and targeted review PASS.

### Owner QA / blockers

Subjective gameplay, dialogue, assets and balance require owner QA after implementation.
Required owner acceptance remains open; explicitly deferred polish gets a QA checklist.

## Mandatory BT pattern

Composites own ordering/fallback/priority/concurrency; Conditions observe; Actions perform
narrow work; Decorators own timeout/repeat/cooldown/invert/limits; Subtrees expose reusable branches.
- Blackboard stores transient context/references, not a hidden mode FSM.
- Domain services may implement algorithms but may not choose among sibling BT behaviors.

Preserve `S_NpcCadence` -> perception/traits -> `S_NpcDecision` and native manual BT updates;
route planning/motion intent and combat keep their existing Systems/physics owners. Do not
add another automatic BT tick or Service clock. Gaze/blood/light emergencies use existing
`NpcDecisionService.request_wake` urgent invalidation; test reaction latency at the actual
decision/physics boundary. Timed trait state stays in its authoritative Component/System.
Long-lived target/zone bindings use Relationships, not a second Blackboard registry.
Architectural acceptance: node names/hierarchy alone must expose high-level NPC decisions.

## Shared top-level tree

Prefer a common root shape with archetype/trait subtrees plugged in:
```text
DynamicSelector
├─ ImmediateSafety / ForcedFreeze
├─ TraitEmergency
├─ ArchetypeCritical
├─ Combat
├─ Blood/Hazard attraction or avoidance
├─ ParcelService
├─ Schedule
├─ Social / dialogue opportunity
└─ Idle / archetype ambient behavior
```

Exact ordering may differ where an archetype requires it, but priority must be visible in the resource.
BT tasks issue semantic intents through existing services; preserve navigation/physics/damage owners.

## Required reusable BT leaves/subtrees

Create reusable, narrowly named tasks where applicable:
- conditions: player visibility/gaze, light thresholds, wounded health, combat target, perceived Blood Hazard;
- actions: authored movement, safe/light/dark flight, watching outside gaze, begin/end combat;
- distance/ranged preference, behind-player approach, freeze, wait/observe, parcel opening;
- hazard-zone entry/retention, cloud escape and visibility/invisibility presentation requests.

Do not force all of these into one generic mega-task with an enum.
## Archetype trees

### Скромник
Prolonged gaze -> warning/escalation -> combat; otherwise observe from a safe angle/distance.
Direct gaze interrupts observation for repositioning; service/schedule remains reachable.

### Плачущий ангел
Highest priority: **player sees/looks at angel -> Freeze**. Unobserved peaceful actors use
schedule/service/approach; aggressive actors pursue/attack at high speed. Observation must
immediately interrupt motion/attack safely through their owners, never per-frame transform
forcing. HOLY-only vulnerability belongs to resistance data. Other NPCs avoid selecting angel
for conflict unless an explicit future rule overrides it.

### Ночной охотник
Visible selector: bright exposure -> authored dark refuge; dark + valid player target ->
attack; otherwise service/schedule. Read authored light zones/circuit state, not renderer
samples. Music/shadows react to appearance/committed state without choosing AI branches.

### Карга
Threat/emergency -> maintain ranged distance/ranged attack -> service/social/schedule.
Grudges may lower aggression thresholds; riddles/deception remain in dialogue.

### Бугай
Witnessed toy -> immediate aggression; strength/respect memory can suppress/end it, then
combat -> private unpacking/service -> threatening social behavior -> ordinary schedule.
Toy witnessing requires real perception and the actual held/opened item category.

### Огненный элементаль
Aura materialization through its idempotent explicit owner -> danger/route -> optional
immediate parcel opening -> combat/service/schedule. Roll explosion once per committed
opening; fire immunity belongs to resistance data. Hazard Systems own aura progression.

### Потерянный
Baseline safety -> ordinary social/aggression combat -> service -> schedule -> social -> idle; no dispatcher.

### Цепной дьявол
Ordinary safety/combat -> anger/escalation -> social soul offer -> service/schedule.
Offers use authoritative dialogue state/cooldown, not tick effects; fire immunity/soul transactions stay outside BT.

### Жуткий
Before detection: terminal-busy/facing-away player -> approach behind; entering visibility
-> stop/reposition/avoid LOS; noticed -> record detection and use normal social/combat.
No teleporting.

### Вампир
Priority: immediate danger -> conditional cloud escape; perceived Blood Hazard -> calm/end
ordinary combat -> enter/stay in zone; wounded player -> controlled feed/attack; light
discomfort adjusts position without unconditional flight; service/social/schedule and optional
invisibility. Ordinary aggression stops before lethal damage at the authored health floor;
future lethal contexts require a separate explicit data/branch rule.

## Interruptions/lifecycle

Every long-running action defines start, RUNNING/SUCCESS/FAILURE and interruption cleanup.
No stale move targets, attack phase, invisibility, reserved booth, hazard interest, or animation state after branch interruption.

## Validation requirements

Focused BT tests prove native composites/conditions, high-priority preemption, clean
interruption, perception without hidden-position knowledge, reuse across trait sets and
deterministic headless behavior with authored seeds.

Near completion run parser + focused GUT + bounded headless district smoke. Rendered feel remains owner QA.
