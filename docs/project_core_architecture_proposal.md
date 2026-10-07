# Project Core Architecture

Status: **TARGET ARCHITECTURE**

Этот документ фиксирует целевое ядро проекта. Его задача — довести проект до состояния, где новый контент в основном собирается из сцен, ассетов, Definitions, Entity Templates / Traits, Smart Objects, Dialogue, AI profiles/schedules и настроек уровней. Новый runtime gameplay-код должен требоваться прежде всего для **новой механики**, а не для нового NPC, предмета, квеста или варианта уже существующей механики.

## 1. Authoritative gameplay model

ECS остаётся единственной authoritative gameplay model.

- `C_*` — intrinsic/config/runtime state или явно документированный derived cache.
- `R_*` — authoritative live Entity-to-Entity relationships.
- `S_*` — scheduled behavior.
- `O_*` — discrete/reactive transitions.
- Services — синхронные domain operations, transactions, lookup/factory boundaries.
- Rules / Calculation / Geometry / Solver — reusable algorithms без скрытого gameplay lifecycle.
- `DEF_*` — immutable/shared authored design data.

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
NPC --R_Reserved--> SmartObjectSlot
```

Одни и те же affordances должны быть доступны игроку, GOAP, LimboAI, quests, Dialogue и tutorials через общий domain contract.

## 6. AI hierarchy

Целевая иерархия:

```text
Authored schedule / world obligations
    ↓
Utility / Goal selection
    ↓
GOAP for macro multi-step planning
    ↓
LimboAI for local execution and reactive behavior
    ↓
Intent / Interaction / Combat systems
```

### Schedule

Для deterministic распорядка использовать authored schedule:

```text
08:00 Work
18:00 GoHome
22:00 Sleep
```

GOAP здесь не нужен.

### Utility / Goal selection

Выбирает текущую цель, например:

```text
Survive
Work
Eat
Sleep
DeliverPackage
Socialize
GoHome
```

### GOAP

GOAP применяется к macro-задачам с несколькими путями достижения.

```text
Goal: Eat

FindFood
→ ReservePlace
→ MoveThere
→ AcquireFood
→ Eat
```

Planner не управляет физикой и realtime боем.

### LimboAI

LimboAI выполняет поведение "здесь и сейчас":
- движение;
- реакцию;
- бой;
- interrupt;
- ожидание;
- animation-driven behavior;
- локальные tactical decisions.

GOAP передаёт LimboAI action/execution contract, но не становится вторым runtime authority.

## 7. AI budgeting and event-driven updates

Reference: Unreal Engine Mass Gameplay — Mass Signals / Mass Simulation LOD / StateTree integration:
https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-mass-gameplay-in-unreal-engine

The useful reference idea is that expensive entity processing can be budgeted/LOD'd and some decision logic can be woken by signals instead of being polled at full frequency. Our AI stack remains Schedule → Utility → GOAP → LimboAI rather than Mass StateTree.


Не каждый NPC обязан думать каждый physics frame.

Ориентир:

```text
Immediate combat/reaction: 30–60 Hz
Nearby perception:         5–10 Hz
Normal decisions:          2–5 Hz
Macro planner:             0.2–1 Hz
Offscreen simulation:      events / game time
```

Planner желательно будить событиями:
- goal invalidated;
- plan finished;
- target disappeared;
- day phase changed;
- hunger threshold crossed;
- reservation lost;
- new job/order appeared.

## 8. Simulation LOD

Reference: Unreal Engine Mass Gameplay — Representation LOD and Simulation LOD:
https://dev.epicgames.com/documentation/en-us/unreal-engine/overview-of-mass-gameplay-in-unreal-engine

We borrow the separation between **simulation detail** and **representation detail**. In this project the concrete implementation is Godot/GECS-specific: physical Node3D + LimboAI near the player, reduced/macro simulation farther away.


Целевые уровни:

```text
LOD0 — рядом с игроком
full Entity + Node3D + physics + LimboAI

LOD1 — активный район
Entity + simplified/reduced-rate AI

LOD2 — далеко
ECS/NpcRecord + schedule/GOAP without physical body

LOD3 — совсем далеко
mathematical/event-based simulation
```

Offscreen NPC не обязан физически проходить маршрут. Достаточно хранить macro state:

```text
travel_target
departure_time
arrival_time
current_macro_goal
```

При materialization физическое представление восстанавливается из authoritative simulation state.

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
- выполнить одноразовый install/setup hook.

Trait **не тикает**.

После materialization Systems видят обычные Components/Relationships и не знают, какими Traits они были созданы.

### 9.1 Trait implementation

Базовые authoring типы:

```text
EntityTrait
DEF_EntityTemplate
EntityBuildPlan
EntitySpawnContext
EntityTemplateCompiler
EntityFactory
```

Рекомендуемый pipeline:

```text
EntityTemplate
    ↓
all Traits contribute
    ↓
EntityBuildPlan
    ↓
validation
    ↓
instantiate / use placed scene
    ↓
materialize Components
    ↓
resolve initial Relationships
    ↓
ECS.world registration
```

`EntityBuildPlan` нужен для проверки конфликтов **до runtime registration**.

Примеры ошибок:
- два Traits пытаются предоставить один incompatible Component;
- `ET_Combat` требует `C_Health`, но template его не предоставляет;
- physical Trait требует совместимый Entity root;
- обязательный binding Home/Workplace отсутствует.

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

### 10.1 Placed и spawned используют один pipeline

Placed Entity:

```text
visible authored scene instance
    ↓
template compile
    ↓
materialize Components/Relationships
    ↓
world registration
```

Runtime spawned Entity:

```text
template.default_scene
    ↓
instantiate
    ↓
template compile
    ↓
materialize Components/Relationships
    ↓
world registration
```

После регистрации Systems не должны различать, был объект поставлен дизайнером или создан factory.

`default_scene` у Template может быть optional: уникальная placed scene может использовать тот же gameplay Template с другим визуальным представлением.

### 10.2 Editor inspector/plugin

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
R_ReservedBy
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
- GOAP action executors;
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

Schedule, GOAP, offscreen simulation и save/restore используют единый game-time contract.

## 16. Seeded deterministic randomness

Важные gameplay decisions используют reproducible seed:

```text
world_seed
+ stable_entity_id
+ game_day
+ decision/action identifier
```

Это нужно для воспроизводимых regression tests и сложных NPC сценариев.

## 17. Gameplay Debugger

Общий debugger дополняет LimboAI debugger.

Для выбранной Entity показывать:

```text
Components
Relationships

AI:
  Current Goal
  Current GOAP Plan
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

После исправления текущего ECS execution model Phase 2 продолжает архитектурную миграцию:

1. vertical domains + dependency boundaries;
2. typed Commands / Events;
3. Entity Templates / Traits;
4. visual authoring/editor validation;
5. Smart Objects / Reservations / Affordances;
6. AI stack: Schedule → Utility → GOAP → LimboAI;
7. Simulation LOD;
8. Content Doctor;
9. unified Game Time + deterministic randomness;
10. Gameplay Debugger;
11. final architecture acceptance.

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
- GOAP is proposed only for macro multi-step planning;
- project Relationships/Commands/Events remain the authoritative integration mechanism.

When an architectural rule is derived from one of these references, documentation/tasks should name the reference explicitly instead of presenting it as an arbitrary local convention.
