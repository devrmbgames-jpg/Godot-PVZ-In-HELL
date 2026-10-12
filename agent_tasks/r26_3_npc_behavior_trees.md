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

Reviewed native freeze/speed/shy/night behavior retains body, animation, combat, cadence and motion authorities. Shy uses actual camera/LOS and safe idle repositioning; Trait System owns gaze escalation. Night uses due-step authored light, reversible combat suppression and native audio/Decal cleanup on dormant/dead/reset/replacement/disposal.
Hag RANGED preference selects visible distance/shot branches in both roots below immediate safety/light/blood. Bounded safe navigation previews preserve physical transform authority; combat owns shots/cooldowns, unreachable retreat permits defense and lost targets use search.
Hag personal grudges derive from durable offender/victim IDs; repeats retain committed reactions and both dialogue roles read the same query. Bodyless promises, days/reset/save retain resentment; no grudge clock. Both hag riddle/deception variants now passed checks/review.
Ranged checkpoint `4140fb04299a2b12597fdab832c913a02a08b172`, grudge `eb3b40d44d9da9e36c1b7d69bc9b36e148b74b42`, repair `510a074b4161f65a67d93fb46d4a5f61a2b62b56`, dialogue `6293c6bdb34334832f0c02e720df11c75cc20dd2`: reviewed PASS. Other mandatory subtrees/live binding remain open.
Brute typed pride uses actual player-camera/solid visibility and NPC recognition of held or opened TOY bodies. Customers samples exposure before cadence; explicit native branches commit one durable offense, while recognized applied strength records actor-specific respect and ends matching combat/panic.
Native toy/catalog and private booth opening retain physical, inspection, order, memory and save authorities. Brain recipes and both authored initial-field policies restore immutable pride and clear transient exposure. Both roots preserve safety/light/blood before toy/combat/service.
Brute checkpoint `b72342b7ab3c08fdd49fa1b9c9ebb55ced9a80b5`: implementation checks and immutable-SHA review PASS. Both strength/private-order dialogue variants `50c2a2ef35cb78d036b96b2087a6bbe920279c21` passed native checks/review; details in R26.4.

### Validation

Earlier native freeze/speed/shy/night checkpoints and RV-001 repair passed checks/review; unique immutable-SHA evidence remains in Git versions of this owner.
Ranged review `4d4866eea7cbff4b22a1845ffc8f3e2c7174de98` -> `4140fb04299a2b12597fdab832c913a02a08b172` PASS, no findings (93 s).
Ranged PASS: parser013605055/12; GUT013520033 9/85, attacks013625559 22/160, blood013633935 10/122, gaze013642158 11/112; authoring013726549 6/38. District-20261012-113652858.log smoke PASS: eight mornings, all phases, save/restore.
Grudge PASS: parser015722064/9 + final015949452/2; GUT020000814 16/153, personal-delivery015733448 31/308, rules015813053 9/63, catalog015831436 4/944. Actual actor-specific reactions, stable save/day/body identity, replay and no-clock due steps ran.
Grudge review `955e8ba636d2c1a4200be6b5ca14c31e0879ea9e` -> `eb3b40d44d9da9e36c1b7d69bc9b36e148b74b42`: R1 accepted as RV-002 (64 s); targeted repair -> `510a074b4161f65a67d93fb46d4a5f61a2b62b56` PASS (8 s).
Repair PASS: parser021131639/2, preflight021037606 7/56, style/static/staged checks. MCP fresh helper diagnostics checked[] PASS; conflict invocation transport UNKNOWN, target hash unchanged/editor clean, invocation not counted PASS. Subsequent native hag pool save passed with one-line disk diff.
Hag dialogue GUT021925998 38/966 and parser022034711/1 PASS; review `9c70cd2c684994a907e35cd74fd01b9bc30e20e7` -> `6293c6bdb34334832f0c02e720df11c75cc20dd2` PASS (119 s); details in R26.4.
Native MCP authoring preserved UIDs/tuning and refreshed caches. Formatter/lint, strict architecture/dependencies, domain/project structure, persistence baseline and staged checks PASS. No extra full smoke for explicit memory/query or authored-dialogue batches; focused actual native lifetimes/roles cover their scope.
Snapshot003124389 tests/exit0 PASS; shutdown retention KNOWN_ENGINE_LIMITATION/DEFERRED. Global reload43 NOT_PASS: verify actual layouts or restart before native saves. Passing runs have no runtime errors/GUT orphan Nodes; reviewer runtime NOT_RUN.
Full mandatory behaviors/live integration and owner rendered movement/dialogue/assets/balance QA remain open.
Brute PASS: parser032455776/23 + final032943100/2; GUT032844552 17/255 (real handoff/opening, two hands, occlusion, respect, codec/reset and synchronous retirement/dormant/reset).
Regression PASS: authoring032618984 3/41, inspection032624264 12/163, grudge/ranged032636637 16/153, gaze032650035 15/110, blood032701361 10/122, shy032714702 11/112, catalog032725024 4/944, orders032929305 7/201. District-20261012-132636729.log PASS: eight mornings, phases and save/restore.
Brute native MCP authored/saved toy, catalog, rule and trees; preserved UIDs and eight embedded supply cases, refreshed caches and restarted clean editor for new globals. Fresh helper/test diagnostics checked[] PASS. Formatter/lint, strict architecture/dependencies, project/domain/persistence/staged/diff PASS.
Rendered Brute gameplay, readability/tone and balance remain owner QA NOT_RUN; reviewer runtime NOT_RUN.
Brute review BASE `8d40a7b0d90e4332778dc896b7304f8a7af7aeaf` -> TARGET `b72342b7ab3c08fdd49fa1b9c9ebb55ced9a80b5` PASS, no findings (122 s); ARCHITECTURE/STYLE PASS, runtime NOT_RUN.

### Next

Implement Fire Elemental's thin 10 m floor Hazard and immediate opening/explosion contract, then the remaining mandatory capabilities before live roster binding.

### Review triage

RV-001 P1 — `bt_npc_begin_dark_hunt._tick` / native update continuation:
FIXED(`b798cfb4817c6d4e05f01a52a66695a9e82b3c71`, hunt001101329 14/125).
Source `a963f56e83f29810238739751780e95041847078` matches current reproduction.
GUT000655821 FAIL: observer removes receiver or resets brain during the hunt fact;
leaf reads a freed actor, brain adapter reads freed runner, scheduler cancels a freed actor.
Repair guards receiver/component/participation and runner identities after publication/update.
Urgent wakes remain cadence invalidation, distinct from reset/participation incarnation.
Native regressions cover retirement, reset/rebind, deferred dormant abort and ordinary hunt.
Targeted immutable-SHA repair review PASS; ARCHITECTURE/STYLE PASS, reviewer runtime NOT_RUN.

RV-002 P1 — `npc_archetype_resave_tool.preflight` used cached external trait values.
FIXED(`510a074b4161f65a67d93fb46d4a5f61a2b62b56`, preflight021037606 7/56).
Source `eb3b40d44d9da9e36c1b7d69bc9b36e148b74b42`; reproduction020450065 FAIL:
unsaved cached gaze-kind edit bypasses the disk graph's mandatory-trait incompatibility.
Deep disk-backed loading isolates added traits and existing compatibility dependencies;
regressions preserve cached unsaved edits and both resource file fingerprints.
Targeted immutable-SHA review PASS; ARCHITECTURE/STYLE PASS, reviewer runtime NOT_RUN.

### Owner QA / blockers

Subjective gameplay, dialogue, assets and balance require owner QA after implementation.
Required owner acceptance remains open; explicitly deferred polish gets a QA checklist.

## Mandatory BT pattern

Composites own control flow, Conditions observe, Actions perform narrow work,
Decorators own execution policy, and Subtrees expose reusable branches.

- Actions are narrow leaf behaviors.
- Composites own ordering/fallback/priority/concurrency.
- Decorators own timeout/repeat/cooldown/invert/limits where applicable.
- Subtrees represent semantic reusable branches.
- Blackboard stores transient context/references, not a hidden mode FSM.
- Domain services may implement algorithms but may not choose among sibling BT behaviors.

Preserve `S_NpcCadence` -> perception/traits -> `S_NpcDecision` and native manual BT updates;
route planning/motion intent and combat keep their existing Systems/physics owners. Do not
add another automatic BT tick or Service clock. Gaze/blood/light emergencies use existing
`NpcDecisionService.request_wake` urgent invalidation; test reaction latency at the actual
decision/physics boundary. Timed trait state stays in its authoritative Component/System.
Long-lived target/zone bindings use Relationships, not a second Blackboard registry.

Architectural acceptance test:

> If leaf implementations are hidden and only node names/hierarchy remain, a reviewer must still understand the NPC's high-level decisions.

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

Do not duplicate navigation/physics/damage logic in BT tasks. Actions issue semantic intents through existing services.

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

Every long-running action must define:
- start;
- RUNNING condition;
- SUCCESS;
- FAILURE;
- interruption cleanup.

No stale move targets, attack phase, invisibility, reserved booth, hazard interest, or animation state after branch interruption.

## Validation requirements

Create focused BT tests proving:
- tree resources have meaningful composites/conditions, not single dispatcher leaves;
- high-priority freeze/light/blood branches preempt lower priority work;
- interruption clears semantic intent correctly;
- no branch performs omniscient perception;
- two NPCs with different trait sets can reuse the same tree/subtrees;
- behavior remains deterministic enough for headless tests with authored seeds.

Near completion run parser + focused GUT + bounded headless district smoke. Rendered feel remains owner QA.
