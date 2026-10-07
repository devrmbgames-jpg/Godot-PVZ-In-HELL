# Project Core Architecture

Status: **PREFLIGHT_TARGET_APPROVED — IMPLEMENTATION_PENDING**

Документ повторно проверен последовательным Phase 0 preflight 2026-10-07; final full review `agent_tasks/refactoring_v2/00_05_preflight_readiness_gate.md` — READY_FOR_IMPLEMENTATION. Runtime/Phase 1 ещё не начаты; следующий запрос начинается с 01 architecture contract. Цель — новый контент преимущественно из сцен, ассетов, Definitions, Templates/Traits, Smart Objects, Dialogue, profiles/schedules и настроек уровней. Новый runtime code нужен прежде всего для новой механики; existing variant обычно создаётся данными.

## 1. Authoritative gameplay model

ECS остаётся единственной authoritative domain/gameplay model. Godot/Jolt сохраняет authority physical transform/velocity; ECS читает эту физическую величину либо выполняет явную одноразовую synchronization при spawn/restore/representation transition. Derived snapshot не является второй физической симуляцией.

- `C_*` — intrinsic/config/runtime state или явно документированный derived cache.
- `R_*` — authoritative live Entity-to-Entity relationships.
- `S_*` — scheduled behavior.
- `O_*` — discrete/reactive transitions.
- Services — синхронные domain operations, transactions, lookup/factory boundaries.
- Rules / Calculation / Geometry / Solver — reusable algorithms без скрытого gameplay lifecycle.
- `DEF_*` — immutable/shared authored design data.

An ECS-owned aggregate may contain typed records/Resources when they have one owner/writer and are validated/serialized through that Component. Per-actor data uses actor Components when queried/mutated per actor; duplicate copies are rejected by authority, not by the mere existence of a Resource. Caches, mirror IDs and terminal history are explicitly marked as derived/immutable.

Не создавать второй gameplay authority в LimboAI Blackboard, GOAP world state, Dialogue, UI, AnimationPlayer или Node tree. Эти слои могут хранить transient/derived working state, но authoritative факт живёт в ECS.

## 2. UI — только Godot glue

UI **не входит в ECS**.

`Control`, HUD, меню и прочая UI-иерархия остаются обычным Godot-кодом.

UI может:
- читать ECS/Domain API;
- подписываться на gameplay events/signals;
- показывать derived state;
- отправлять typed Commands/Requests.

UI не должен:
- создавать UI Components только ради отображения;
- участвовать в ECS scheduling;
- становиться владельцем gameplay state;
- менять внутренности Components напрямую, если существует domain command.

Пример:

```text
Button pressed
    ↓
UI glue
    ↓
BuyItemRequest
    ↓
Commerce domain
    ↓
ItemPurchased
    ↓
UI refresh
```

## 3. Commands → Events

Закрепить общий паттерн:

```text
Request / Command
    ↓
authoritative gameplay handler
    ↓
state mutation
    ↓
Event / Outcome
```

Примеры:

```text
DamageRequest → O_Damage → DamageApplied → HealthDepleted
BuyItemRequest → Commerce → ItemPurchased
InteractRequest → Interaction → InteractionStarted
```

Commands/Requests означают намерение выполнить изменение. Events/Outcomes означают уже произошедший authoritative факт.

Transport — существующий GECS targeted event/request path либо synchronous domain operation. Не вводить global EventBus, wildcard registry, generic dispatcher или retry/saga framework. Payload immutable snapshot; request имеет target/operation identity. Deferred submit reports accepted/pending, committed result confirms completion; a synchronous operation may return committed directly under its explicit contract. One handler owns a command; multiple fact consumers own distinct idempotent effects, presentation listeners read-only. Reactions publish after coherent commit; reentrant cycles are review failure. Deferred structural work has an explicit flush boundary: deps alone does not flush a PER_GROUP buffer.

Цель — уменьшить `Service → Service → Service` coupling и позволить нескольким системам реагировать на результат без скрытого call graph.

## 4. Stable simulation pipeline

Целевой coarse pipeline:

```text
External / Input
    ↓
Intent
    ↓
AI / Decision
    ↓
Navigation / Interaction preparation
    ↓
Physics
    ↓
Gameplay Resolution
    ↓
Outcomes / Lifecycle
    ↓
Presentation notifications
```

Внутри фаз используются `deps()`. Разработчик должен понимать порядок исполнения без чтения service call graph.

Это logical flow, не требование заменить четыре существующие World groups семью новыми. Baseline сохраняет Input → Interaction → Physics → GamePlay из main_level; internal ordering задаётся `deps()`, callback solvers сохраняют Godot timing. Изменение phase latency требует отдельного before/after contract test.

## 5. Smart Objects / Affordances

Reference: Unreal Engine Mass Gameplay — Mass SmartObject integration:
https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-mass-gameplay-in-unreal-engine

This is a conceptual reference for capability-based world interaction and reservations. We are not adopting Unreal SmartObject runtime classes; the project keeps its own ECS Relationships, Definitions and Godot scene markers.


Мир должен объявлять доступные действия вместо проверки конкретных типов объектов.

Примеры:

```text
Bed
  Sleep
  slots: 1

Chair
  Sit
  slots: 1

DeliveryCounter
  DeliverPackage
  slots: 1

Fridge
  AcquireFood
```

Reservations выражаются через Relationships:

```text
NPC --R_Reserved(slot_id, token)--> SmartObject
```

Одни и те же affordances доступны игроку, LimboAI, quests, Dialogue и tutorials через общий domain contract. Future optional GOAP будет consumer того же API, не обязательным участником baseline.

Acquire checks eligibility/exclusivity atomically at mutation execution, including deferred requests. Pending enqueue is not a reservation. Token carries world/session and object incarnation plus acquisition sequence; it cannot cancel a new object/world reservation with the same stable ID. Occupancy is derived from R_Reserved, marker path is local authoring and slot_id is durable content identity.

## 6. AI hierarchy

Mandatory preflight baseline:

```text
Authored schedule / world obligations
    -> Bounded goal/obligation selection
    -> LimboAI local execution and reactive hierarchy
    -> Intent / Interaction / Combat owners
```

Schedule defines obligations and game timestamps. Goal selection stores the selected obligation in ECS and defines priority/interruption/cancellation. Pure normalized utility scoring with hysteresis is optional when goals genuinely compete; no separate Utility runtime is mandatory.

LimboAI retains local/emergency/combat decision flow in its native tree. Macro selection does not duplicate selectors inside a leaf and never controls physics. Action adapters request work from the owning domain; that owner confirms completion/failure and releases intent/reservation on cancellation.

**GOAP - DEFER.** Existing schedule/route/service jobs do not demonstrate a need for alternative macro search. GOAP is excluded from mandatory Refactoring v2 acceptance; no placeholder planner classes. Future evidence gate: an authored goal with alternative multi-step paths that is substantially less readable as a schedule/subtree, plus bounded search, observability and interruption tests. Such a feature requires a separate optional task. Its world state would be a derived ECS view.

## 7. AI budgeting and event-driven updates

Reference: Unreal Engine Mass Gameplay — Mass Signals / Mass Simulation LOD / StateTree integration:
https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-mass-gameplay-in-unreal-engine

The useful reference idea is budgeting expensive work and waking relevant decisions with targeted notifications. Our baseline uses schedule/goal selection and LimboAI; GOAP and StateTree integration are not required.


Не каждый NPC обязан думать каждый physics frame.

Ориентир:

```text
Immediate combat/reaction: 30–60 Hz
Nearby perception:         5–10 Hz
Normal decisions:          2–5 Hz
Optional future planner:   0.2–1 Hz
Offscreen simulation:      events / game time
```

Goal selection желательно будить событиями:
- goal invalidated;
- action/obligation finished;
- target disappeared;
- day phase changed;
- hunger threshold crossed;
- reservation lost;
- new job/order appeared.

Budget ownership is per expensive responsibility (perception/decision/repath), using existing Systems and queues, not a new global AI scheduler. Work units have authored per-tick caps, stable fair cursor/order and bounded coalesced wake flags; every eligible NPC has a bounded wait. Urgent damage/interrupts are handled by their owners immediately and cancel stale work. Diagnostics report due/processed/deferred work and maximum wait; tests include a burst exceeding budget and starvation. Frequencies above are tuning examples, not a performance guarantee. No elapsed-milliseconds cutoff in deterministic fixtures and no broad world search per actor per frame.

## 8. Simulation LOD

Conceptual reference: [Mass Gameplay](https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-mass-gameplay-in-unreal-engine) separates representation cost from simulation cadence. Borrow the separation of concerns; a detachable representation is not necessary for the current Godot population.

```text
ACTIVE  - existing physical-root GECS Entity, Godot physics/navigation + LimboAI
DORMANT - same registered Entity/body retained, hidden/frozen, no collision/nav/BT
Simulation cadence/budget is independent of engine participation.
```

Keep the physical-root NPC and visible scene contracts. C_District.people is an ECS-owned aggregate: NpcRecord owns identity/history/schedule placement, actor Components own HP/inventory/local action, Relationships own live links. A nested Resource inside a Component is not a second runtime database. Mirror identity fields are immutable references; death_day is terminal history of a C_Death outcome, not a competing live health/death rule. No second mutable mode/location copy or live offscreen DTO store. The authority table in task 45 covers each field and its single writer.

Mode derives from authoritative participation/placement and active-session pins. Dormant bodies remain allocated; this baseline reduces update/physics cost, not memory. Existing World.disable_entity may exclude the actor from ordinary queries; the NPC population System queries the enabled aggregate and explicitly resolves registered dormant actors by stable ID. Do not rely on default enabled-only queries for save/restore, cleanup or schedule progression. Godot owns transform/velocity; dormant position is not a second physical simulation. Existing home/outside/day-phase behavior remains; no new offscreen travel/economy/combat mechanics.

A transition generation prevents repeated participation/arrival/outcomes. Held items, combat, dialogue and active slot use pin ACTIVE, or are cancelled through owners before dormancy. Preserve durable home/work assignments, release transient sessions. Reactivation validates placement at a safe physics boundary and never repeats arrival/settlement; blocked placement has bounded retry with a reason, then a defined failure. Cadence hysteresis prevents active/dormant oscillation.

Street NPCs do not disappear merely because the camera looks away. Active reduced cadence is independent; response latency is bounded/tested. Dormant hunger/health/timer behavior follows existing absence policy, not a blanket catchup calculation or a new offscreen outcome path.

**Body detach/lightweight actor shell, offscreen travel, four tiers and population aggregation - DEFER** until measured memory/physics/CPU cost cannot meet the actual population budget with dormancy/cadence. A future detach task must migrate all casts, collider-to-owner resolution, BT agents, scenes/exports and save adapters before DONE. No placeholder shell/provider/alternate execution path in Refactoring v2.

## 9. Entity Templates / Traits

Reference: Unreal Engine Mass Entity — Entity Templates and Traits:
https://dev.epicgames.com/documentation/unreal-engine/overview-of-mass-entity-in-unreal-engine?lang=en-US

We intentionally borrow the **authoring/composition idea** from Mass: an Entity Config/Template is composed from Traits, and Traits contribute/configure the runtime data needed for a capability. Our implementation remains native to Godot + GECS and does not copy Unreal runtime APIs.


Traits — **authoring recipes**, а не runtime Components и не Systems.

Trait описывает capability и знает, какие runtime pieces нужны для неё.

Примеры:

```text
ET_PhysicalCharacter
ET_DialogueParticipant
ET_Hunger
ET_Combat
ET_Trader
ET_Resident
ET_Customer
ET_QuestGiver
```

`DEF_EntityTemplate` собирает Traits.

```text
DEF_EntityTemplate: ResidentTrader

Traits:
  ET_PhysicalCharacter
  ET_DialogueParticipant
  ET_Resident
  ET_Trader
  ET_Hunger
```

Trait при compilation/materialization может:
- добавить Component recipe;
- сконфигурировать Component;
- добавить initial Relationship intent;
- указать required scene capability;
- зарегистрировать Definition/profile references;
- объявить required setup adapter из ограниченного capability contract; произвольные side effects в compiler запрещены.

Trait **не тикает**.

После materialization Systems видят обычные Components/Relationships и не знают, какими Traits они были созданы.

### 9.1 Trait implementation

Minimal roles, rather than six mandatory standalone public classes:

```text
EntityTrait + DEF_EntityTemplate
    -> compile/validate operation
    -> transient EntityBuildPlan + typed spawn-context contract
    -> existing factory / placed scene preparation
    -> World.add_entity and GECS _initialize
    -> endpoint Relationship fixup
    -> composition-ready publication
```

The plan validates incompatible providers, missing requirements and scene capabilities before registration. Flat composition, no Template inheritance. The compiler is side-effect-free; arbitrary install hooks are rejected. A standalone compiler/context/factory class is justified only by a real boundary.

Pinned authority: addons/gecs/ecs/entity.gd, world.gd, ecs.gd and observer.gd. World discovers placed Entities and initializes Components while synchronously notifying Observers. Project glue prepares fresh recipes before super._initialize, does not register placed scenes twice, and uses public World/CommandBuffer lifecycle APIs. Gameplay consumers require composition-ready and completed world startup; endpoint fixup/restore completes before simulation. Failure prevents ready publication and cleans up partial registration. Cleanup cannot undo external side effects; gameplay commands/outcomes are forbidden before ready, passive engine bindings are permitted.

GECS copies top-level Components shallowly. Nested mutable containers/resources must be isolated explicitly; Definitions remain shared immutable. on_changed requires explicit property_changed notification or an owning typed outcome; direct assignment does not automatically notify. Build fixtures prove nested-state isolation, placed/spawned parity and load without HP reset or repeated setup.

Placed startup needs a project-owned World/bootstrap hook **before** automatic World.initialize/add_entities: pass an explicit World build context, compile all placed recipes, validate duplicate IDs/endpoints, then run the pinned World lifecycle once. Do not assign ECS.world early for compilation: its setter finalizes System.setup immediately, and add_system sets up immediately when that world is active. A project World subclass/glue performs one-shot preparation before its superclass ready path; addons remain read-only. Validation only inside Entity._initialize is too late to prevent ID-collision replacement. Normal ECS.world binding/setup remains passive until startup spawns, saved-state overlay and endpoint fixup finish; then publish ready before main_level simulation. Runtime factory follows the same gate for each new Entity. Entity.on_ready, engine callbacks and synchronous Observers must not publish gameplay effects during construction/restore. This is explicit startup glue, not another scheduler or generic lifecycle framework.

### 9.2 Trait invariants

Trait — immutable/config authoring data.

Нельзя:

```text
ET_Combat.current_target
ET_Trader.current_customer
ET_Hunger.current_value
```

Runtime state живёт в:

```text
C_NpcCombat
R_CombatTarget
C_Hunger
...
```

Trait должен быть composable. Capability определяется composition, а не наследованием concrete NPC классов.

Trait application должна быть deterministic:

```text
same template + same definitions + same spawn context
→ same runtime composition/configuration
```

### 9.3 Trait vs Definition

```text
Trait      = capability wiring
Definition = tuning/content
Component  = runtime state
System     = scheduled behavior
Observer   = reactive behavior
```

Например `ET_Combat` не должен хранить десятки боевых параметров. Он ссылается на `DEF_CombatProfile`.

### 9.4 Relationships and SpawnContext

Trait может требовать binding, но не обязан знать конкретную runtime Entity.

```text
ET_Resident requires:
  home
  workplace
```

`EntitySpawnContext` предоставляет instance-specific bindings:

```text
home → House_12
workplace → Shop_04
owner → Player_1
spawn_position → ...
world_seed → ...
```

## 10. Visual scene authoring remains primary

Traits **улучшают scene authoring, но не заменяют его**.

Для authored уровня действует правило:

> Поставил NPC или объект на сцену — видишь настоящий NPC или объект в Godot Editor.

Пример:

```text
City.tscn

├── Building
├── DeliveryCounter
├── Boris : E_DistrictNpc
├── Alice : E_DistrictNpc
├── Chair
└── TrashBin
```

У `Boris` в Inspector:

```text
Entity Template: ResidentTrader
NPC Profile: Boris

Bindings:
  Home → House_12
  Workplace → Shop_04
```

Scene отвечает за:
- mesh/skeleton;
- collision;
- animation nodes;
- navigation/markers;
- world presentation;
- authored physical structure.

Template/Traits отвечают за gameplay capabilities.

Profile/Definitions отвечают за конкретный content/tuning.

Instance bindings отвечают за контекст конкретного экземпляра на уровне.

### 10.1 Minimal authoring contract

Для варианта существующей capability используются visible scene instance и нужный Profile; reusable composition использует existing Template, а простой declarative scene-only object не требует empty Template. Template можно хранить inline; отдельный `.tres` создаётся при переиспользовании. Новый `ET_*` script нужен для новой capability, а не для каждого NPC или предмета. Template inheritance в baseline отсутствует; композиция плоская, через reusable Traits и Profiles.

Resolved precedence: scene owns mesh/collision/animation/node paths and declarative intrinsic/engine-glue Components; optional Template owns reusable capability recipes; Profile owns tuning; instance owns stable ID, bindings and enumerated initial overrides. Scene-only declarative Entity is valid and passes the same preparation/validation path, without an empty Template asset. All procedural capability installers migrate under a closed manifest in 41; a migrated capability cannot also be installed by old on_ready/factory code. GECS receives each provider exactly once, including pure define_components output. Duplicate providers fail unless field merge is explicitly declared; no last-Trait-wins. Save overlay follows defaults and precedes ready, preserving HP/inventory.

Inspector показывает Template/Profile, stable ID и named bindings в Simple mode; Advanced раскрывает resolved providers, conflicts и source provenance. Compile/validate — одна entry point для Inspector, factory и headless Doctor. Preview read-only и не изменяет shared Resources, save или gameplay world. Error указывает resource, placed instance, binding/field и owning capability.

Local authoring Node references удобны для выбора Home/Workplace/slot marker. Build context переводит их в authored stable ID и проверяет принадлежность нужному world; runtime Entity binding появляется только при fixup. Duplicating scene instance требует нового instance ID; tool предлагает repair явно и не молча переименовывает gameplay identity.

Smart Object slot не требует отдельной GECS Entity: `actor --R_Reserved(slot_id, token)--> object`. `slot_id` — authored stable ID внутри объекта; marker NodePath — локальный scene binding, а не durable identity. Это сохраняет scene/Inspector workflow и bounded relationship count.

### 10.2 Programmer / debugger / agent workflow

Owner определяется `content/domains/<owner>/<role>/`; public payload/API находятся в `contracts/`, внутренние записи там не становятся public автоматически. Каждая task начинает с owner + direct contract + smallest regression surface. Новая capability добавляет recipe/requirements, System/Observer только для нового поведения и validation provider в тот же milestone.

Command trace несёт origin, target stable ID, operation/correlation ID и явный accepted/rejected/completed result. Bounded diagnostic snapshot включает source of selected goal, rejected options, active action, cancellation reason, intent, reservation owner/token и cadence/representation mode. State consumers read-only; recent-event ring bounded и включается для выбранной Entity, не логирует каждый мир/frame. LimboAI tree debugger остаётся отдельным native inspector.

Debug provider возникает вместе с contract; task 48 объединяет views. GOAP fields отображаются только если такой optional planner когда-либо введён. Configuration error, command rejection и runtime action failure — разные причины, которые не маскируются общей ошибкой «invalid».

### 10.3 Placed и spawned используют один pipeline

Placed Entity:

```text
visible authored scene instance
    ↓
template compile
    ↓
prepare recipes before GECS initialization
    ↓
World initialization + endpoint fixup + composition-ready
```

Runtime spawned Entity:

```text
PackedScene selected by the existing Definition / level / spawn caller
    ↓
instantiate
    ↓
template compile
    ↓
prepare recipes before GECS initialization
    ↓
World initialization + endpoint fixup + composition-ready
```

После регистрации Systems не должны различать, был объект поставлен дизайнером или создан factory.

Scene owns its Template reference; factory receives a PackedScene plus typed context/Profile, instantiates it and compiles that instance's Template. Template does not own a default_scene back-reference. This avoids a Scene → Template → PackedScene resource cycle and competing scene selectors in NPC Profile vs Template. Existing Definition scene selection migrates explicitly, without another mandatory SpawnDefinition wrapper. Multiple visual scenes may use the same flat gameplay Template.

### 10.4 Editor inspector/plugin

Нужен небольшой editor tooling слой, а не отдельный runtime framework.

Inspector выбранной Entity должен показывать:
- Template;
- Profile/Definitions;
- resolved Traits;
- preview runtime Components;
- required bindings;
- validation diagnostics.

Simple mode — для дизайнера.
Advanced mode — resolved composition/build diagnostics для программиста.

Editor preview может обновлять presentation (`@tool`): appearance, markers, Smart Object slots, facing directions.

Editor preview **не запускает ECS simulation, GOAP, Hunger, CustomerFlow и другие runtime Systems**.

### 10.5 Dialogue and quest authoring boundary

Dialogue Manager remains the imported dialogue/branch renderer. Typed `ctx` exposes narrow observational predicates and owning action methods; no world/Entity/service object is exposed for arbitrary mutation. The existing Customer/NPC contexts and panel remain the integration points. Conditions cannot commit gameplay. Cues/tags and context methods are declared by the owning dialogue contract, not inferred from displayed text.

An action uses a stable session/operation identity and an explicit committed/rejected/pending result. A success branch waits for committed outcome; accepted submission alone is insufficient. Re-entering a branch cannot pay or issue a quest twice. Awaited lines/actions verify the original session and actor/visit generation before use; closing, death, target loss and load close the session and release modal focus/reservations. Retain the pinned DialogueResourceLifecycle cleanup for late async results.

Quest baseline is the existing refusal/delivery/event-driven lifecycle, not an arbitrary quest DSL or graph executor. Task 19 makes the existing quest Definition author-selectable through its owner/issuer configuration instead of a hardcoded singleton; variants select existing rules and change reward/deadline/targets/Dialogue. A new objective or effect kind is a new mechanic and needs owner code, validation and fixtures. No global string action registry or universal expression interpreter.

Doctor validates imported dialogue/cues and declared context/tag references without executing mutations. Dynamic expressions beyond the supported surface require an explicit bounded review/test; static checking does not prove arbitrary script semantics. Two distinct quest/dialogue variants and repeated-entry/late-result fixtures are acceptance, not a claim of universal no-code quests.

## 11. Capability-driven gameplay

Gameplay предпочитает composition вместо проверки concrete entity class.

Избегать:

```text
if entity is E_Customer
if entity is E_Trader
```

Предпочитать:

```text
has C_CustomerAgent
has C_Trader
has C_DialogueParticipant
has C_NpcCombat
```

Concrete Godot Entity class остаётся там, где нужен конкретный physical/presentation implementation.

## 12. Relationships

Relationships использовать для live links:

```text
R_CombatTarget
R_AssignedTo
R_Reserved
R_Follows
R_TradingWith
R_DialogueWith
R_QuestTarget
R_HomeOf
R_WorkplaceOf
```

Не дублировать authoritative Relationship ещё одним mutable Entity field без причины.

## 13. Authoring vs Runtime

Authoring:

```text
.tscn
.tres
Dialogue resources
markers
Traits
Entity Templates
Smart Objects
profiles/definitions
```

Runtime:

```text
Components
Relationships
Systems
Observers
typed events/requests
```

Не выполнять постоянные `find_child`, `get_nodes_in_group` и `ResourceLoader` lookup в hot paths, если данные можно подготовить при setup/materialization.

## 14. Content validation

Нужен headless Content Doctor.

Он проверяет:
- Entity Templates;
- Traits и их зависимости;
- required Components;
- required bindings;
- referenced Dialogue;
- Smart Object executors;
- existing action executors; GOAP checks only if optional planner is introduced;
- schedule locations;
- animation names;
- stable IDs;
- definition ranges;
- resource paths;
- scene capability requirements.

Цель — content errors ловятся до запуска уровня.

## 15. Unified Game Time

Чётко разделить:
- simulation delta;
- physics frame;
- game clock;
- day index / phase;
- world timestamp;
- real/UI time.

Schedule, goal selection, dormant processing и save/restore используют explicit game-time contract. World timestamp — monotonic integer elapsed simulation ticks with an explicit quantum/remainder; C_DayCycle remains authority player-driven day/phase transitions. Daily deadlines/phase schedules use calendar labels/events, local delays use elapsed ticks; no inferred automatic day length. Pause stops gameplay elapsed time; sleep/skip emits calendar transition without inventing elapsed night duration. Preserve existing phase behavior; physics callback delta and UI clock are separate. Save persists authoritative tick/remainder/calendar state; reload does not reset overdue work or replay phase outcomes.

## 16. Seeded deterministic randomness

Важные gameplay decisions используют reproducible seed:

```text
world_seed
+ stable_entity_id
+ game_day
+ decision/action identifier
+ persisted decision sequence when repeated decisions require it
```

Это нужно для воспроизводимых regression tests и сложных NPC сценариев.

Seed derivation использует фиксированное canonical byte encoding/hash, stable iteration order и explicit counter persistence; engine/process hash не является durable determinism contract. Jolt lockstep не требуется.

## 17. Gameplay Debugger

Общий debugger дополняет LimboAI debugger.

Для выбранной Entity показывать:

```text
Components
Relationships

AI:
  Current Goal
  Active obligation/action (optional GOAP plan only if introduced)
  Current Action
  LimboAI task/status

Intent
Reservations
Perception
Simulation LOD
Recent gameplay events
```

Gameplay debugger — часть ядра проекта.

## 18. Vertical domains

Крупная кодовая база организуется в первую очередь по gameplay domain ownership, а не только по технической роли.

Целевой layout:

```text
content/
├── domains/
│   ├── combat/
│   │   ├── components/
│   │   ├── relationships/
│   │   ├── systems/
│   │   ├── observers/
│   │   ├── services/
│   │   ├── rules/
│   │   ├── solvers/
│   │   ├── definitions/
│   │   ├── entities/
│   │   ├── authoring/
│   │   ├── ai/
│   │   ├── dialogue/
│   │   ├── scenes/
│   │   └── ui/
│   ├── npc/
│   ├── customers/
│   ├── interaction/
│   ├── commerce/
│   ├── quests/
│   ├── packages/
│   ├── time/
│   └── persistence/
│
├── shared/
│   └── <canonical role folders only>
│
├── ui/          # global Godot Control glue
├── scenes/      # global composition/entry scenes
├── materials/
└── debug/
```

Не каждый domain обязан иметь каждый role folder.

Но если роль существует, имя каталога каноническое. Нельзя иметь в одном domain `components/`, а в другом `component/`, `camponent/` или `Components/`.

Canonical role folders проверяются `utils/validate_domain_structure.py`.

Во время миграции:

```bash
python utils/validate_domain_structure.py
```

После полного vertical-domain migration:

```bash
python utils/validate_domain_structure.py --strict
```

Strict mode дополнительно запрещает legacy horizontal gameplay roots.

Owners baseline: `npc`, `customers`, `interaction`, `combat`, `motion`, `packages`, `hazards`, `commerce`, `inventory`, `quests`, `challenges`, `needs`, `time`, `persistence`. Population/district schedules and their configuration belong to npc: they operate on the same personalities and lifecycle, so a separate district domain adds a cyclic boundary without independent ownership. Hunger — needs; wallet/purchase — commerce; receiving/delivery — packages; input/focus — interaction; camera/locomotion — motion. Shared требует нескольких реальных consumers, не превращается в universal gameplay service. Empty roles не создавать.

Runtime direction: shared kernel не импортирует domains; leaf capability contracts feed npc and customers; quests/challenges consume producer-owned facts; persistence imports declared snapshot adapters. File/symbol implementation dependency graph must be acyclic, including behavioral public API imports. A coarse domain graph may contain reciprocal references to declared leaf data/read/query/fact contracts when the actual implementation graph has no cycle and writer authority remains one-way; do not add wrappers/shared copies merely to make this coarse graph a DAG. Public visibility alone does not authorize an edge. Domains do not import persistence: startup/autosave wiring belongs global composition. Customers imports npc capabilities; npc base code cannot import customer implementation/classes. Customer-specific trees/adapters belong customers. Asset graph is separate.

Cross-domain Dialogue contexts/UI-opening routing live in existing global Godot glue, not shared kernel or a base NPC class. Move panel/resource/context construction out of domain start methods; domains expose begin/end/eligibility/session outcomes and never import global UI. Composition binds public APIs/facts without owning gameplay timers/state; relocations replace existing responsibility, no forwarding registry. Task 28 records source→target symbols plus read/query/request/subscription rights and forbidden writes. Task 33 separately checks actual file/symbol cycles and coarse domain edges. Authored assets (package→hazard scene) do not mask runtime cycles.

Task 28 уточняет file-to-owner map по inventory 10 в рамках этой policy. Public `contracts/` имеют explicit symbol/path manifest; перенос internal класса в папку не разрешает dependency. Validator 33 индексирует class_name; arbitrary dynamic imports запрещены вне declared adapters и проверяются review/content scan.

Explicit public data/capability contracts могут экспортировать owning `C_*`, Profile или Trait из canonical role paths (например read/query C_Health), без forwarding script в contracts/. Manifest сохраняет writer authority: import/query не разрешает другому domain менять HP/relationship/lifecycle через private fields. Write authority проверяется ownership review и behavioral fixtures; path validator не доказывает semantics.

Домены общаются через:
- typed commands;
- typed events;
- stable domain API;
- explicit shared low-level contracts.

Не через произвольный доступ большого Service к внутренностям другого domain.

## 19. Full-refactor invariant

Если объявлен полный архитектурный refactor, нельзя считать этап завершённым при permanent dual architecture.

Запрещённый финал:
- старый и новый execution path одновременно;
- wrappers/aliases, оставленные только чтобы не обновлять callers;
- файлы перемещены, но ownership не изменён;
- половина domain осталась в horizontal roots;
- новый validator держится на бессрочном allowlist известных нарушений.

Temporary adapters допустимы только внутри незавершённого milestone и удаляются до DONE, если внешний compatibility contract не требует иного.

## 20. Target roadmap inside Refactoring v2

Phase 2 начинается с inventory 10 и typed-contract foundation 40 до execution migration 11–27; последующие owners сразу используют готовые boundaries. Затем архитектурная миграция продолжается (IDs задач — stable identifiers, а не sort order):

1. execution acceptance (27), включая final typed Commands / Events flows из 40;
2. vertical layout contract (28) + dependency validator (33);
3. domain moves (29–32), strict dependency/layout rerun;
4. unified Game Time + deterministic randomness (47);
5. Entity Templates / Traits (41);
6. visual authoring/editor validation (42);
7. Smart Objects / Reservations / Affordances (43);
8. AI decision/execution contract (44);
9. Simulation LOD (45);
10. Content Doctor aggregation (46);
11. Gameplay Debugger view (48);
12. final architecture acceptance (49).

Validation и diagnostic providers добавляются в owning milestone 40–45, а не впервые в 46/48. Identity/schema baseline определена задачей Phase 1.04 до любых execution/path migrations.

Только после стабильной архитектурной baseline выполняется массовый Code Style pass.

## 21. Критерий зрелого ядра

Ядро считается зрелым, когда:
- новый NPC обычно не требует нового runtime-кода;
- новый торговец собирается из Template + Traits + stock + Dialogue;
- новый quest собирается из Definitions + Events/Conditions + Dialogue;
- новый предмет собирается из Traits/Definitions + scene/presentation;
- новый район собирается из scenes + Smart Objects + schedules + NPC templates;
- новая механика требует нового System/Observer/Rules;
- новая разновидность существующей механики требует в основном данных;
- designer видит реальные NPC/объекты в Godot Editor и получает validation до запуска игры.


## References and borrowed ideas

The target architecture is project-specific. The following external systems are used as **design references**, not as APIs to reproduce mechanically.

### Unreal Engine Mass Entity / Mass Gameplay

- Mass Entity overview — Entity Manager, Entity Templates, Traits, deferred entity operations:
  https://dev.epicgames.com/documentation/unreal-engine/overview-of-mass-entity-in-unreal-engine?lang=en-US
- Mass Gameplay overview — Representation LOD, Simulation LOD, Signals, StateTree integration, Smart Objects:
  https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-mass-gameplay-in-unreal-engine
- Mass Observer Processor:
  https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/MassEntity/UMassObserverProcessor

Ideas explicitly inspired by Mass:
- Entity Templates assembled from composable Traits;
- Traits as authoring/configuration of runtime capabilities rather than per-frame behavior;
- scheduled processors vs reactive observers;
- deferred/command-buffer structural mutations;
- separate representation LOD and simulation LOD;
- signal/event-driven wake-up of expensive logic;
- Smart Object integration as a reusable interaction capability.

Project-specific differences:
- GECS v8 remains the ECS runtime;
- Godot scenes remain the primary visual/physical authoring representation;
- UI remains ordinary Godot Control glue;
- LimboAI remains local/realtime behavior execution;
- GOAP, detachable bodies and four-tier LOD are deferred; the baseline uses existing obligations, LimboAI and active/dormant participation;
- project Relationships/Commands/Events remain the authoritative integration mechanism.

When an architectural rule is derived from one of these references, documentation/tasks should name the reference explicitly instead of presenting it as an arbitrary local convention.

### Flecs observers

[Flecs Observers manual](https://www.flecs.dev/flecs/ObserversManual.html) distinguishes periodic Systems from event reactions and documents notification costs. Borrowed: genuine transitions and explicit delivery semantics. Rejected: composition changes solely to send ordinary events and assuming direct assignment notifies automatically. Actual GECS semantics come from pinned local source.

## 22. Phase 0 scope decisions

- ADOPT: minimal flat Templates/Traits, one validation path, scoped typed contracts, existing-object affordances/reservations, active/dormant participation, ECS-owned aggregates with per-field authority, time/seed contract, early content/diagnostic providers.
- REJECT: Template inheritance/default_scene cycle, arbitrary install hooks, global bus/framework, default slot Entity, separate district ownership, blanket seven-group scheduler replacement, generic quest/action interpreter.
- DEFER: GOAP, mandatory Utility framework, body detach/lightweight actor shell, new macro travel, four tiers/aggregated population, new Sit/Sleep mechanics solely as demos.
- Owner decision 2026-10-07: old save migration/backward compatibility не требуется. Changed format bumps schema и отклоняет unsupported saves до live mutation. New-format identity/roundtrip/links обязательны; tooling не удаляет/перезаписывает пользовательские файлы.

Persistence baseline remains Night-only prepared-Morning snapshots: finish evening/reset/prepare once, drain owning structural/outcome work, then capture immutable data and write. A failed write retry does not repeat settlement/preparation. Restore preflights all IDs/recipes/resources/endpoints without effects, constructs defaults, overlays saved state, reconstructs durable links/caches/participation and publishes ready last. Invalid preflight leaves live state untouched; unexpected startup failure abandons the unfinished World. No universal undo system or arbitrary mid-action checkpoint is implied by LOD save tests.

Authored actor IDs are world/level-scoped local IDs, spawned IDs are persisted domain sequences. Definition IDs, actor keys, GECS ecs_id and operation IDs have different meanings. NpcRecord and C_NpcIdentity reference one actor; the resolver/reverse indexes are derived. Durable IDs survive path moves and explicit scene duplication repair. Stable bindings are restored after every endpoint exists, including dormant registered actors.

Task 04 specifies identity/version baseline; task 25 implements stable placed IDs and removes path-derived key/restore matching before moves 28–32. Task 41 adds composition/duplicate-ID gates and 42 explicit editor ID repair. Tests prove node rename/reparent does not change identity or links. No legacy key aliases or save converters.

Это preflight design decisions, не реализованные runtime capabilities. Phase 1 не начата. Rationale/scorecards находятся в owning 00_* tasks.
