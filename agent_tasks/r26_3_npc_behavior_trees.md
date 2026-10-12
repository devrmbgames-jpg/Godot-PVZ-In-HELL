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
Real NPC sight recognizes clouds and rejects invisible bodies; schema18 excludes transient forms.
Review **REVIEW_PENDING**: BASE `a2b1d764b1b316b27df979a8d72917d6deab8ed8`
-> TARGET `588b59c1771d95b4ffba278988ddef0a364013a7`, same terminal reviewer reused.
Final-code district smoke RUNNING; the pre-final FLEE guard smoke failed survival5/required6.
Local light comfort `38b7f2a59ef3c344b03aafaf11e7f7911d60622c` adds typed reusable
CAPABILITY data excludes emergency light aversion; a visible idle branch preserves higher priorities. Selection uses close authored activity/cover,
actual authored light, synchronized navigation and zero-damage routes; no teleport or offense.
Native movement handles interruption/abandonment; companion MCP authors bounded native BTCooldown.
Review BASE `8608f987f2a2a8965597829be98c2d6a7a8e94df` -> that TARGET **PASS**:
same reviewer, no findings, architecture/style PASS (210s); reviewer validation NOT_RUN.
Feeding `3961328cdc94dc93d56fa7336373af993128e0da` GUT123/1830;
review BASE `80eb932ff485fd714e8b111ea370629de3ec3f2f` PASS, no findings (91s).
Underlying Health bound `792481e4630d1ca70156654d3a22a1a91fd94cef`, blood consent
`a407762ef018ab70715119cd432c63071d62d928` and20/20 native dialogue variants are reviewed.
Schema18 restores durable consent receipts without live mutation. Unique previous evidence is in Git.
All-ten live binding, full integration and required owner QA remain open.

### Validation

Cloud batch GUT **136/2406 PASS**, `.artifacts/godot_agent/`, date20261012:
Veil20324494715/127; participation2025201979/162; sight2026361738/27;
native lifecycle20313622251/346; feeding20323005711/95; light20324240812/159;
night20265103420/186; catalog2027054844/944; variation2027088306/360.
Parser20273604220files plus final2032045052files PASS; formatter, strict architecture/domain,
structure, staged index, diff and persistence gates PASS. Final smoke RUNNING.
Pre-final `tests/artifacts/district-20261013-062736299.log` FAIL, survival5/required6;
not evidence for final code. Prior light-week PASS remains in Git. Global hot reload43 NOT_PASS;
fresh CLI checks independently verify. Required editor/rendered verification remains open.
Passing runs have no runtime errors/GUT orphan Nodes. Specified shutdown-only retention
KNOWN_ENGINE_LIMITATION/DEFERRED. Full mandatory/live/rendered behavior and owner QA remain open.

### Next

Collect immutable cloud review and final smoke; resolve findings/failures before acceptance.
Then cross-archetype acceptance and all-ten live roster binding; do not waive R26.5/owner QA.

### Review triage

Canonical source/fix SHAs below are ancestors of current code HEAD
`588b59c1771d95b4ffba278988ddef0a364013a7`; prior light/feeding/blood/UI reviews added no findings.
Full-SHA ancestry audit: 26 previous checkpoints PASS. RV-001..005 retain FIXED with their
actual regression/re-review evidence. Current cloud review is REVIEW_PENDING, not PASS.

RV-006 P1 FLEE_EXIT continuation, Main reproduction/source
`a2b1d764b1b316b27df979a8d72917d6deab8ed8`, NpcDecisionService.flee:
FIXED `588b59c1771d95b4ffba278988ddef0a364013a7`; baseline202020933 freed-actor access.
Veil20324494715/127 and lifecycle20313622251/346 PASS, including native reset/retirement,
normal dormant fear cleanup and direct role-release API. Targeted review REVIEW_PENDING.

RV-005 P1 continuous camera exposure, source `3e88b56983a775cc78c225353251ff6a98d33b87`, R1/Main:
FIXED `23fa3d44d9024d4becb59477921be1d288d7bee9`, GUT18342894914/111, parser1834543174/4.
HOME/STREET baseline183345914 FAIL13/14: suspension retained0.4s then0.1s and committed detection.
Repair resets transient sensing before runner lookup, preserving memory; targeted review PASS.

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
