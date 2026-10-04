# R26.3 — LimboAI Behavior Trees for NPC archetypes
Status: **PLANNED**

Parent: `agent_tasks/r26_items_npc_expansion.md`

## Goal

Implement the requested NPC behaviors as **real Behavior Trees** using LimboAI v1.8.1.

Load and follow `.agents/skills/limboai-v1.8/SKILL.md`.

The tree hierarchy must expose decision flow. Do not reproduce the current anti-pattern where one configurable `BTAction` calls a generic service that secretly selects/executes an entire behavior branch.

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

Expected visible structure:
- prolonged direct gaze condition -> warning/escalation -> combat;
- otherwise observe player from a safe angle/distance;
- if player starts looking directly -> break gaze/reposition;
- service/schedule remains reachable when not threatened.

### Плачущий ангел

Highest-priority condition:
- **player currently sees/looks at angel -> Freeze subtree**.

When not observed:
- peaceful: schedule/service/approach as authored;
- aggressive: high-speed pursuit/attack;
- if observed again, immediately interrupt motion/attack and freeze.

Freeze must actually stop movement intent/attack execution safely; it must not fight the physics owner by directly forcing transforms every frame.

Only HOLY damage vulnerability belongs to damage resistance, not BT.

Other NPC conflict selection must treat angel as a target to avoid unless an explicit future rule overrides it.

### Ночной охотник

Visible selector:
- bright exposure -> flee to authored darker refuge;
- dark + valid player target -> attack;
- otherwise service/schedule.

Music/shadow warning is a presentation side effect/event around appearance/state transition, not a hidden AI switch.

### Карга

- threat/emergency;
- maintain ranged distance;
- ranged attack preference;
- grudge/memory may lower aggression threshold;
- service/social/schedule;
- riddles/deception stay in dialogue, not combat BT logic.

### Бугай

- witnessed toy embarrassment -> immediate aggression;
- strength/respect memory can suppress or end aggression;
- combat;
- private unpacking/service preference;
- threatening social behavior;
- ordinary schedule.

Toy witnessing must use perception condition and real held/opened item category.

### Огненный элементаль

- maintain/ensure aura through narrow action/owner service;
- danger/route logic;
- optional immediate parcel opening;
- relevant parcel explosion chance is authored once per opening event, not rolled every tick;
- combat/service/schedule.

Fire immunity belongs to resistance data, not BT.

### Потерянный

Use as baseline tree:
- safety;
- combat only from ordinary social/aggression rules;
- service;
- schedule;
- social;
- idle.

No special dispatcher.

### Цепной дьявол

- ordinary safety/combat;
- anger/escalation;
- social opportunity can offer soul trade;
- service/schedule;
- repeated soul-offer cadence controlled by dialogue state/cooldown, not every tick.

Fire immunity and soul stat mutations remain outside BT.

### Жуткий

Before detected:
- if player is busy at terminal / facing away -> approach behind;
- if entering player's direct visibility -> stop/reposition/avoid LOS;
- if player notices it -> mark detection and transition to normal social/combat behavior.

No teleporting.

### Вампир

Priority:
- immediate danger -> cloud escape when conditions allow;
- perceived Blood Hazard -> calm/end ordinary combat -> enter/stay in blood zone;
- wounded player opportunity -> controlled attack/feed behavior;
- light discomfort influences path/position but is not unconditional flee;
- service/social/schedule;
- optional invisibility behavior.

Ordinary vampire aggression must stop before killing the player according to authored health floor. Explicit future lethal contexts may override via separate data/branch.

## Interruptions/lifecycle

Every long-running action must define:
- start;
- RUNNING condition;
- SUCCESS;
- FAILURE;
- interruption cleanup.

No stale move targets, attack phase, invisibility, reserved booth, hazard interest, or animation state after branch interruption.

## Validation

Create focused BT tests proving:
- tree resources have meaningful composites/conditions, not single dispatcher leaves;
- high-priority freeze/light/blood branches preempt lower priority work;
- interruption clears semantic intent correctly;
- no branch performs omniscient perception;
- two NPCs with different trait sets can reuse the same tree/subtrees;
- behavior remains deterministic enough for headless tests with authored seeds.

Near completion run parser + focused GUT + bounded headless district smoke. Rendered feel remains owner QA.
