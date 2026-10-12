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

Native feeding `3961328cdc94dc93d56fa7336373af993128e0da` adds typed reusable policy and
visible wounded-player/floor branches to both native roots. Active service/conversation remain
protected; ordinary melee and launched projectiles capture the generic common Health bound.
No offense is fabricated, HP below the floor never rises, blood/safety preempt feeding.
Review BASE `80eb932ff485fd714e8b111ea370629de3ec3f2f` -> that TARGET **PASS**:
same terminal reviewer, no material findings, architecture/style PASS (91s), reviewer tests NOT_RUN.
Underlying queued Health bound `792481e4630d1ca70156654d3a22a1a91fd94cef` and blood consent
`a407762ef018ab70715119cd432c63071d62d928` passed independent reviews; exact evidence
remains in Git. Schema18 restores durable current-HP consent receipts without live mutation.
R26.4 has20/20 native dialogue variants. Vampire dialogues
`14cadff37461590c14454aabfdbca1fb4af11e94` passed native GUT78/2014 and review (50s).
Cloud/light, all-ten live roster binding, full integration and required owner QA remain open.

### Validation

Feeding GUT **123/1830 PASS**: Feeding19353022011/95; Blood19333610810/122;
Stalking19335153814/111; GazeAversion19340695411/113; Ranged1939126179/85;
GazeFreeze19334952415/110; Dark19340189714/125; Vampire19393593939/1069.
Logs under `.artifacts/godot_agent/`, date20261012. Fresh parser193937821 **16files PASS**;
formatter/lint, strict architecture/dependencies, project, agent/index, diff and persistence PASS.
Bounded headless week PASS: `tests/artifacts/district-20261013-053937434.log`.
Global hot reload43 NOT_PASS; fresh CLI parser/GUT independently verify code. Editor cursor4 clean.
Passing runs have no runtime errors/GUT orphan Nodes. Specified shutdown-only retention
KNOWN_ENGINE_LIMITATION/DEFERRED. Full mandatory/live/rendered behavior and owner QA remain open.

### Next

Implement typed light discomfort without unconditional flight and conditional cloud/visibility,
then
cross-archetype acceptance before live roster binding.

### Review triage

Canonical source/fix SHAs below are ancestors of current code HEAD
`3961328cdc94dc93d56fa7336373af993128e0da`; feeding and preceding blood/UI/Health-bound
reviews added no findings. RV-001..005 retain FIXED with their actual regression/re-review evidence.

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
