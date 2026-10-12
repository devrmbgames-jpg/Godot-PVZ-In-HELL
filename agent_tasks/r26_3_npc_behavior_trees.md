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

Latest Creepy checkpoint `3e88b56983a775cc78c225353251ff6a98d33b87` implements hidden native routes,
actual camera/LOS stop, terminal-reader reach and durable actor-specific notice (schema17).
Recovery review BASE `6f96be1e39eb94b4a4c307c8bce2d3b9a30a14f3` -> that TARGET collected;
only R1 accepted as RV-005. Repair `23fa3d44d9024d4becb59477921be1d288d7bee9`
passed independent targeted re-review (27s); reviewer was reused after its terminal result.

Reviewed native freeze/speed/shy/night behavior retains body, animation, combat, cadence and motion authorities. Shy uses actual camera/LOS and safe idle repositioning; Trait System owns gaze escalation. Night uses due-step authored light, reversible combat suppression and native audio/Decal cleanup on dormant/dead/reset/replacement/disposal.
Hag RANGED preference selects visible distance/shot branches in both roots below immediate safety/light/blood. Bounded safe navigation previews preserve physical transform authority; combat owns shots/cooldowns, unreachable retreat permits defense and lost targets use search.
Hag personal grudges derive from durable offender/victim IDs; repeats retain committed reactions and both dialogue roles read the same query. Bodyless promises, days/reset/save retain resentment; no grudge clock. Both hag riddle/deception variants now passed checks/review.
Brute typed pride uses actual player-camera/solid visibility and NPC recognition of held or opened TOY bodies. Customers samples exposure before cadence; explicit native branches commit one durable offense, while recognized applied strength records actor-specific respect and ends matching combat/panic.
Native toy/catalog and private booth opening retain physical, inspection, order, memory and save authorities. Brain recipes and both authored initial-field policies restore immutable pride and clear transient exposure. Both roots preserve safety/light/blood before toy/combat/service.
Brute checkpoint `b72342b7ab3c08fdd49fa1b9c9ebb55ced9a80b5`: implementation checks and immutable-SHA review PASS. Both strength/private-order dialogue variants `50c2a2ef35cb78d036b96b2087a6bbe920279c21` passed native checks/review; details in R26.4.

Fire presence uses separate authored torso sphere and thin 10 m floor Cylinder; generic Hazard owners retain follow, overlap damage and teardown. Route and sleep risk clip floor height. Checkpoints `0daa93c2898a19b28f5c827a4e81b5436b67e9c8` and RV-003 repair `2fbd959480f0c2ff5f028d7ba012651634ea9fe8` passed checks/targeted review. Immediate physical opening and one durable ignition roll now passed checks/review at `952c851545d2a4b28954a6a620cd0dfbbe8582e5`; both Fire dialogue variants `044de4285d22ff67c53635fbff5596d3dab7cbf6` passed native tests and review. Existing service BT and Hazard owners execute opening/inspection/blast, with eligible physical item and actual opener facts.

Soul core `3a18bbc5275463d05328744e767e923cf8242d7b` commits +1 Strength/-10 maximum Health and the third total acceptance through common depletion. Refusals preserve count; closure keeps the pending key. Captured terms, durable receipts/cooldowns, schema16 and native player capability preserve save/lifetime authorities. Independent review and RV-004 repair PASS; both Chain variants `fd7fbd0fe70d682c4af5e9454525d5cf08b0fa1b` passed native checks and independent review.

### Validation

Recovered Creepy evidence: stalking06245473113/99, interaction0622085098/76,
freeze06221985615/110, aversion06223225711/113, parser0626376215/5 PASS.
Recovery review247s accepted RV-005 only; baseline183345914 FAIL13/14, fix18342894914/111 PASS.
Formatter/lint34files vs recovery base, strict architecture/dependencies, domain/project/persistence
and diff PASS after public-dialogue contract update. Connected district headless smoke PASS: `tests/artifacts/district-20261013-043550631.log`.
Historical source-checkpoint smoke162810446 also PASS; neither is rendered QA.


Chain dialogue GUT054458560 39/945, parser054654245/2 and fresh MCP checked[] PASS;
review BASE `b2fa6988d8ff5abf378ac11d28de6d7b5d298412` ->
TARGET `fd7fbd0fe70d682c4af5e9454525d5cf08b0fa1b` PASS, no findings (59 s); details R26.4.

Latest soul PASS: GUT053521718 16/186, native packed authoring052140988 4/328,
contact052230683 6/40, world052321580 35/443; parser052429308/25.
MCP saved native trait/profile/player with preserved UID/recipes; fresh tests checked[].
District-20261012-152551456.log smoke PASS. Formatter/lint, strict architecture/dependencies,
project/domain/persistence/diff PASS. Incremental gate's ResourceSaver REVIEW accepted by independent review as editor-only native authoring.
Baseline052241040 5/362 assertions PASS; runner FAIL solely shutdown retention.
Review BASE `f89a150b439a78473848ffe416eca306085ed0d4` ->
TARGET `3a18bbc5275463d05328744e767e923cf8242d7b`, repaired/reviewed `4f956de8db9a62aa8bd13df53c150025798aa1d0` PASS.
Reviewed Fire presence/opening/dialogues and Brute milestones above passed focused
GUT/parser/static/smoke and immutable reviews; unique evidence remains in those checkpoints.
Earlier freeze/speed/shy/night/ranged/grudge/hag checks and immutable reviews passed.
RV-001/RV-002/RV-003 repairs remain recorded below.
Global hot reload43 NOT_PASS; actual layouts/restart and fresh CLI checks independently verify changes. Passing runs have no runtime errors/GUT orphan Nodes. Specified shutdown-only retention KNOWN_ENGINE_LIMITATION/DEFERRED.
Full mandatory behavior/live integration and owner rendered movement/dialogue/assets/balance QA remain open.

### Next

Implement Vampire
mandatory capabilities/two variants and cross-archetype acceptance before live roster binding.

### Review triage

RV-005 P1 `S_NpcStalkingWitness._sample` / uninterrupted camera exposure:
source `3e88b56983a775cc78c225353251ff6a98d33b87`, reviewer R1, owner Main.
Same NPC/player suspension retained0.4s then0.1s incorrectly committed durable detection.
FIXED(`23fa3d44d9024d4becb59477921be1d288d7bee9`, gut18342894914/111).
Actual HOME/STREET regression baseline183345914 FAIL13/14 reproduces unwanted memory;
repair resets transient sensing before native runner lookup, preserves durable memory.
Parser1834543174/4 PASS; independent targeted re-review ARCHITECTURE/STYLE PASS, no findings.

RV-004 P2 fatal threshold101 created an invalid ledger at `3a18bbc5275463d05328744e767e923cf8242d7b`.
FIXED(`4f956de8db9a62aa8bd13df53c150025798aa1d0`, Soul053521718 16/186, parser053544530/2).
Boundaries0/101 preserve ledger;1/100 produce valid offers. Targeted review PASS.

RV-001 P1 native hunt publication/update lifetime:
FIXED(`b798cfb4817c6d4e05f01a52a66695a9e82b3c71`, hunt001101329 14/125).
Source `a963f56e83f29810238739751780e95041847078`; retirement/reset/dormant
regressions and targeted immutable review PASS. Original evidence remains in Git.

RV-002 P1 cached native trait preflight:
FIXED(`510a074b4161f65a67d93fb46d4a5f61a2b62b56`, preflight021037606 7/56).
Source `eb3b40d44d9da9e36c1b7d69bc9b36e148b74b42`; detached disk validation
and targeted review PASS. Original live cache reproduction remains in Git.

RV-003 P1 ? `S_NpcTraits._advance_traits` continued after synchronous aura publication.
FIXED(`2fbd959480f0c2ff5f028d7ba012651634ea9fe8`, fire041956067 11/77).
Source `0daa93c2898a19b28f5c827a4e81b5436b67e9c8`; baseline041905500 reproduced freed-body access and writes after dormancy/reset through actual System query/CommandBuffer.
Repair rejects changed world, receiver availability/enabled/death, Component identities and participation generation before later trait rules/blood reads; ordinary live continuation remains covered. Targeted immutable-SHA review PASS.

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
