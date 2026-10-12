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

Reviewed freeze/speed retain body/animation, combat, cadence and motion authorities.
Reviewed shy idle observation/repositioning uses actual camera/LOS and safe routes;
S_NpcTraits owns exposure and one remembered prolonged-gaze attack. Interruption releases
only the owned movement/look. Reviewed night hunting samples authored light at due steps,
shares reversible combat suppression and preserves replacement emergency movement.
RV-001 receiver-retirement/reset repair and targeted review passed. Reviewed native night
audio/Decal presentation clears Tweens/audio on dormancy, death, reset/replacement and disposal.
The hag's existing RANGED preference now selects a visible native distance/attack subtree in
street and customer roots below immediate safety/light/blood. Separate Conditions and Actions
hold firing distance during cooldown or request at most three safe navmesh previews through
NpcRouteSolver; existing combat owns shots and physical bodies own transforms.
Unreachable retreat permits existing close-range defense; lost targets use existing search.
MCP replacement prepares an isolated fingerprinted graph and preserves resource UID/Blackboard.
Ranged checkpoint review PASS, no findings. Goal resumed.
Typed hag resentment now derives from durable personal incidents by stable offender/victim IDs;
new interactions gain a bounded attack bonus, while repeats retain the committed reaction.
Bodyless promises keep personal victim identity; days/body reset/save preserve resentment.
Both dialogue roles share a read-only view; Trait System creates no grudge clock.
Grudge checkpoint `eb3b40d44d9da9e36c1b7d69bc9b36e148b74b42` and RV-002 repair
`510a074b4161f65a67d93fb46d4a5f61a2b62b56`: checks and targeted review PASS.
Both hag riddle variants, other mandatory subtrees and live roster binding remain open.

### Validation

Earlier freeze/speed/shy/night checkpoints passed native checks and independent review;
historical immutable-SHA evidence remains in Git versions of this owning task.
Ranged review BASE `4d4866eea7cbff4b22a1845ffc8f3e2c7174de98` ->
TARGET `4140fb04299a2b12597fdab832c913a02a08b172` PASS, no findings (93 s).
Ranged PASS: parser013605055/12; GUT013520033 9/85, attacks013625559 22/160,
blood013633935 10/122, gaze013642158 11/112; authoring-tool013726549 6/38.
District-20261012-113652858.log smoke PASS: eight mornings, all phases, save/restore.
Grudge PASS: parser015722064/9 + final015949452/2; native GUT020000814 16/153,
personal-delivery015733448 31/308, rules015813053 9/63, catalog015831436 4/944;
native resave preflight015303465 5/42. Actual actor-specific social reactions, stable
save/day/body identity, incident replay and due-step no-clock behavior ran.
Native MCP created/added the typed trait with root UID/tuning preserved and refreshed cache.
Classless test/helper diagnostics checked[] PASS. Formatter/lint, strict architecture/dependencies,
domain/project structure, persistence baseline and staged incremental architecture PASS.
No extra full smoke for the explicit memory/query batch; focused native checks cover its scope.
Snapshot003124389 tests/exit0 PASS; shutdown-only retention is KNOWN_ENGINE_LIMITATION/DEFERRED.
Global reload43 remains NOT_PASS: confirm actual exported layouts or restart before native saves.
Original night music/shadow and rendered movement/dialogue feel remain owner QA.
Grudge review BASE `955e8ba636d2c1a4200be6b5ca14c31e0879ea9e` ->
TARGET `eb3b40d44d9da9e36c1b7d69bc9b36e148b74b42`: R1 accepted as RV-002 (64 s).
Targeted repair review -> `510a074b4161f65a67d93fb46d4a5f61a2b62b56` PASS (8 s).
Repair PASS: parser021131639/2, native preflight GUT021037606 7/56, style/static/staged checks.
MCP script diagnostics checked[] PASS; native conflict invocation transport outcome UNKNOWN,
target SHA-256 unchanged and editor scenes clean. This invocation is not counted as PASS.
Passing runs have no runtime errors/GUT orphan Nodes. Reviewer runtime VALIDATION NOT_RUN.
Full mandatory behaviors/live roster integration and owner gameplay/visual QA remain open.

### Next

Implement both hag riddle/deception variants and the
remaining mandatory archetype capabilities before live roster binding.

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
