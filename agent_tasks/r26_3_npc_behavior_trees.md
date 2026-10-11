# R26.3 — LimboAI Behavior Trees for NPC archetypes
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Implement the requested NPC behaviors as **real Behavior Trees** using LimboAI v1.8.1.

Follow [limboai-v1.8](../.agents/skills/limboai-v1.8/SKILL.md) and
[game-ai](../.agents/skills/game-ai/SKILL.md).

The current `bt_npc_action.gd` is a narrow movement/lifecycle base; `NpcDecisionService`
exposes explicit operations, and current trees already expose branch selection. Extend this
model. A single configurable leaf dispatching an entire decision tree remains prohibited.

### Current

Reusable observation-freeze capability is implemented: typed authored trait, compiler input,
frame-rate camera/frustum/solid-LOS sampling before cadence, urgent invalidation, native body
freeze and animation pause, stationary avoidance and attack-boundary gates. R_CombatTarget
survives the interruption. Native MCP inserts the visible safety subtree after terminal state
and before danger/blood/combat. The angel catalog uses the trait; the live roster is not rebound.
Reset/reused restore rebuild transient state and selected capability without rerolling variation.
Observation checkpoint review PASS. Next: aggressive speed and remaining mandatory subtrees.
No complete archetype behavior acceptance is claimed; traits compose without an NPC-ID dispatcher.

### Validation

Observation GUT222305503 PASS 11/11, 75 asserts, native camera/LOS/Jolt/animation/manual BT.
Regression PASS: cache222111743 6/77; variation222116292 6/360; catalog222119532 4/944;
attacks222155017 22/160; identity222203373 13/102; participation222209670 12/133;
world snapshot222227075 35/443. No GUT orphan Nodes or runtime errors.
Parser222334705 PASS (20 owned scripts); formatter/lint, strict architecture/domain structure,
dependencies, project structure and persistence baseline PASS. District smoke PASS:
tests/artifacts/district-20261012-082437905.log (eight mornings/all phases/save/restore).
MCP leaf diagnostics checked[]/reloaded PASS; global class reload43 NOT_PASS, CLI verified.
MCP saves both brain policies with complete initial fields; exact guarded cache refresh proves
the selected rule field in the live cache without file/UID changes; clean scene reload PASS.
Review BASE 7d1a4b2dfefb840e30fba336389da367f1d5f8b2 ->
TARGET 71c592dc86e292b0a2cbc8f772e7025adcb965c5 PASS, no findings (99 s).
ARCHITECTURE/STYLE PASS; reviewer runtime VALIDATION NOT_RUN.
NOT_RUN: full mandatory archetype behaviors, roster integration and owner gameplay/visual QA.

### Owner QA / blockers

Subjective gameplay, dialogue, assets and balance require owner QA after implementation.
Required owner acceptance remains open; explicitly deferred polish gets a QA checklist.

## Mandatory BT pattern

Use the Behavior Tree pattern:

```text
Composite
├─ Condition
├─ Action/Subtree
├─ Decorator
└─ ...
```

- Conditions observe and normally have no side effects.
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
- player-visible / player-looking-at-NPC condition;
- light-above / light-below threshold condition;
- health/player-wounded condition;
- has combat target;
- has perceived Blood Hazard;
- move to authored target/zone;
- flee to safe/light/dark destination;
- watch player without entering gaze;
- begin/end combat;
- maintain distance / ranged preference;
- approach behind player;
- freeze movement;
- wait/observe;
- open parcel request;
- enter/stay in hazard-interest zone;
- cloud escape;
- visibility/invisibility presentation request.

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
Baseline tree: safety -> ordinary social/aggression combat -> service -> schedule -> social
-> idle. No special dispatcher.

### Цепной дьявол
Ordinary safety/combat -> anger/escalation -> social soul offer -> service/schedule.
Offers use authoritative dialogue state/cooldown, not repeated tick effects. Fire immunity
and soul stat transactions remain outside BT.

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
