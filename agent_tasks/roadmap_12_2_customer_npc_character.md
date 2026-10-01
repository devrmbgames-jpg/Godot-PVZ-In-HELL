# R12.2 — Полноценный физический NPC / Customer character foundation

Status: **OWNER_QA**

## Task state

### Goal
Превратить `Customer` из узкоспециализированного `CharacterBody3D` с отдельным `CustomerMotionService` в полноценного физического NPC на общей character-архитектуре проекта: общий Controller/Motion/Look, физическое тело примерно того же класса поведения, что Player, голова/направление взгляда и переиспользуемый NPC intent layer. Customer-specific код должен отвечать за визит, диалог и бизнес-состояния, а не за базовую физику персонажа.

### Constraints / acceptance
- This is a Feature-level tracked task.
- Зависимости: R08, R11, R12.1.
- Godot 4.7 + Jolt; физический transform/velocity принадлежат физическому body, без покадрового teleport/set_position как locomotion.
- Не создавать вторую формулу locomotion/look/impact специально для Customer. Переиспользовать `E_RigidBodyCharacter`, `C_Controller`, `C_Motion`, `C_Look`, `CharacterMotionSolver`, `CharacterLookSolver` и существующий impact contract.
- `C_PlayerInputController` остаётся marker только игрока. NPC не должен попадать в `S_PlayerInput` / `S_PlayerIntent`.
- Components хранят data/state; NPC behavior находится в System/service/solver. Customer flow не получает authority над физической velocity.
- Сохранить текущие Customer contracts: schedule/visit identity, dialogue, interaction actions, direct handoff, counter delivery, refusal/follow-up, health/death/outcome.
- Не ломать Player, Grab/Carry/Push/Cart и существующие physics contracts при выделении общего character foundation.
- Не добавлять сложный combat AI: R17 использует подготовленный здесь NPC foundation.
- Не требовать новых animation assets; если текущая character library уже содержит подходящие Idle/Walk, подключить их без создания отдельного animation subsystem.

### Milestones
- [x] M1. Выделить общий physical character foundation из текущей player-oriented scene без регрессии Player.
- [x] M2. Добавить generic NPC intent/controller data contract для move/look target и System, который пишет semantic intent в `C_Controller`.
- [x] M3. Перевести `Customer` на общий RigidBody character foundation и удалить Customer-only ownership физического движения.
- [x] M4. Подключить head/look behavior Customer и минимальное locomotion presentation (Idle/Walk, если уже доступно).
- [x] M5. Мигрировать CustomerFlow на generic NPC commands/intents, сохранив все текущие visit/dialogue/delivery semantics.
- [x] M6. Добавить focused GUT + headless physics/customer regression coverage.
- [x] M7. Независимо проверить diff; все material findings завершить как FIXED / ACCEPTED / FALSE_POSITIVE.
- [x] M8. Передать owner gameplay/visual QA.
- [x] M9. User-requested NavigationAgent3D + real pathfinding/navmesh integration.
- [x] M10. Validate wall detour and customer-flow arrival using navigation waypoints.

### Decisions
- `C_CustomerAgent` остаётся customer-domain state: visit/phase/service lifecycle. Generic movement/look state не должен жить в Customer-only component.
- NPC и Player используют один physics solver path. Различается источник intent: Player — input systems, NPC — NPC intent system.
- NPC physics не должен читать `CustomerVisit` каждый physics tick. Customer domain один раз/по событию задаёт generic target/config; character physics работает независимо от customer subsystem.
- Arrival/target tracking — generic NPC concern. Customer phase transitions читают generic arrived/result state, но не вычисляют velocity.
- Look target и move target независимы: NPC может идти в одну точку и смотреть на Player.
- По уточнению пользователя NPC использует NavigationAgent3D и warehouse NavigationRegion; waypoint adapter принадлежит generic NPC layer, body velocity остаётся в shared physics callback. Direct movement отключается при ожидании карты или отсутствии пути.
- R17 должен иметь возможность переключить того же NPC из service behavior в pursuit/attack без замены физического тела или параллельной locomotion системы.

### Current
Base migration committed as 7464a941. NavigationAgent3D extension implemented and validated on 2026-10-02: Customer follows actual waypoints; warehouse map initially contained 121 baked polygons (R13 clearance rebake: 122). Includes offline rebuild utility and pending/blocked state. Next implementation: resume R13 environment joints/light circuits.

### Validation
- R13 follow-up: actual waypoint tolerance is 0.35 after removing an unsupported hash comment in scene text. Wall-detour smoke PASS. Main customer_flow and handoff now strictly PASS after project level purge cleanup; dialogue fixture retains two script resources for R23. Warehouse map rebaked to 122 polygons.
- Navigation extension: strict npc_navigation smoke PASS (wall detour, initial zero target, 1800-frame budget); focused NPC GUT 6/6 tests, 22 assertions PASS. Main customer_flow completes all physical delivery/dispute assertions, but strict teardown currently FAIL (31 resources associated with ongoing R13 openable/action resources). Navigation bake utility saved 121 polygons; same scene teardown retention is reported. Structure validation PASS.
- Godot 4.7.1 / GUT 9.7.1: test_npc_intent + test_customer_dialogue + test_customer_flow: 45/45 tests, 323 assertions PASS. Shutdown reports 3 ObjectDB / 2 Resource leaks, so this is assertion evidence rather than clean teardown evidence.
- Player main-scene grab regression: 1/1 test, 58 assertions PASS with clean shutdown.
- Strict headless smoke PASS: customer_flow (2400 frames), character_contact (360 frames), npc_character (2400 frames). NPC smoke proves obstacle blocking, external impulse retention, arrival recovery, existing Idle/Walk availability and shared head look.
- Direct-handoff smoke reaches all wrong/delivered/refused grip assertions and prints PASS; strict runner FAIL for 29 resources at shutdown. Customer-dialogue smoke reaches lifecycle PASS but strict runner FAIL for existing RID/resource leaks also seen before this migration. Clean teardown follow-up belongs to final R23 validation.
- Existing next-day test fixture lacked a registered package; corrected to match production registration-gated arrival.
- Project structure validation PASS after restoring missing explicit System.group metadata in main_level while preserving other local scene changes. git diff --check PASS. gdtoolkit unavailable; no formatter run claimed.
- Headless editor cache refresh completed, but reported AssetPlacer assertions and sandbox-denied editor-settings save; this is not a clean editor validation.

### Review
- Independent read-only reviewer: no material findings in the migration. Shared Player node/body contracts and NPC relationship lifecycle checked.
- R1 (BUG, existing shutdown resource retention in dialogue/handoff surfaces): ACCEPTED for R12.2 scope; gameplay assertions pass, clean teardown remains required by R23. No addon modification made.

### Owner QA / blockers
Требуется owner QA после реализации:
- Customer физически приходит к стойке, ждёт и уходит как раньше.
- Во время ожидания/диалога Customer естественно смотрит на Player; голова и корпус не дёргаются.
- Коробки/другие RigidBody физически мешают NPC; NPC не проходит сквозь них и не телепортируется.
- Сильный физический impulse/impact реально сдвигает Customer; после стабилизации NPC способен продолжить движение к цели.
- Прямой handoff в руках, counter delivery, dialogue/refusal/follow-up остаются рабочими.
- Player movement/look/grab/push/cart не изменились после выделения общего character foundation.

---

Зависимости: R08, R11, R12.1
Ветка/base: master / 06019cfa (R12 visible intent prefixes).
Источники: [Customers](../docs/customers.md), [Gameplay context](../content/CONTEXT.md), [R12.1](roadmap_12_1_customer_refusal_negotiation.md), [R17](roadmap_17_combat_and_impact_damage.md).

## Проблема сейчас

Текущий `Customer` — отдельный `CharacterBody3D` с капсулой и `CustomerMotionService`. Сервис каждый physics tick читает `CustomerVisit`, сам формирует velocity/gravity и вызывает `move_and_slide()`. Это делает Customer специальным исключением из character physics проекта.

Одновременно в проекте уже существует более общий физический персонаж:
- `E_RigidBodyCharacter` на `RigidBody3D`;
- `C_Controller` как semantic intent;
- `C_Motion` + `CharacterMotionSolver`;
- `C_Look` + `CharacterLookSolver`;
- HeadY / HeadX и look target;
- Health/Living/Impact contracts;
- физическое взаимодействие с Jolt, impulses и другими телами.

Нужно не развивать второй Customer-only character stack, а сделать Customer специализацией общего NPC/character stack.

## Начать здесь

- [Customer scene](../content/entities/customers/customer.tscn)
- [Customer entity glue](../content/entities/customers/e_customer.gd)
- [Generic NPC commands](../content/services/motion/npc_intent_service.gd) (replaces removed CustomerMotionService)
- [Generic rigid-body character](../content/entities/characters/e_rigid_body_character.gd)
- [Generic character scene](../content/entities/characters/e_rigid_body_character.tscn)
- [Controller](../content/components/gameplay/c_controller.gd)
- [Motion solver](../content/services/motion/character_motion_solver.gd)
- [Look solver](../content/services/motion/character_look_solver.gd)
- [Player intent](../content/systems/input/s_player_intent.gd)
- [Customer flow](../content/services/customers/customer_flow_service.gd)

## ТЗ / архитектура

### 1. Общая character foundation

Текущая `e_rigid_body_character.tscn` фактически одновременно является generic character и Player prefab: в ней уже лежат `C_PlayerInputController`, Jump/Crouch, Grab/Carry/Push, player interaction anchors и camera/head nodes.

Нужно разделить понятия:
- **общий physical character** — тело, collision, Controller, Motion, Look, Health/Living/Impact, head axes и минимальные presentation hooks;
- **Player specialization** — player-input marker, jump/crouch, grab/carry/push, camera/interaction slots и другие player-only contracts;
- **NPC specialization** — generic NPC intent/data + нужные конкретному NPC gameplay components;
- **Customer specialization** — CustomerAgent, Interactable/actions и customer-domain data поверх NPC specialization.

Допустим scene inheritance/composition; точное имя нового prefab выбирается при реализации. Главное — не дублировать solver physics между Player и Customer.

### 2. Generic NPC controller / intent

Добавить data-only компонент уровня `C_NpcController` / `C_NpcIntent` (имя уточнить при реализации), который как минимум умеет хранить:
- активность locomotion;
- move target как world position и/или live Entity target;
- arrival distance;
- arrived / blocked/progress runtime state, если это нужно для phase logic;
- look target отдельно от move target;
- режим взгляда: target / movement / hold current;
- authored speed multiplier/override только как intent/config, не как физическая velocity.

Добавить `S_NpcIntent` (или эквивалентный System), который:
- выбирает актуальную world-space цель;
- пишет только `C_Controller.direction_motion` и `C_Controller.direction_look`;
- при arrival останавливает semantic motion;
- не меняет transform/linear_velocity напрямую;
- не знает о `CustomerVisit`, пакетах, диалогах или Terminal;
- не обрабатывает Player entities с `C_PlayerInputController`.

### 3. Физика NPC

Customer должен двигаться через тот же `CharacterMotionSolver`, что физический Player character:
- RigidBody3D/Jolt;
- mass/physics material/collision profile задаются character scene/data;
- внешние impulses и столкновения сохраняются;
- floor traction/friction работает тем же путём;
- physics callback остаётся владельцем изменения body velocity;
- impact capture подключён тем же generic contract.

NPC не обязан иметь Player-only способности:
- jump;
- crouch;
- grab/carry;
- push control;
- player camera/input.

Они подключаются только если это понадобится отдельной задачей.

### 4. Голова и взгляд

Использовать существующий `C_Look`, `CharacterLookSolver`, HeadY/HeadX и доступный skeleton look target.

Минимальное поведение Customer:
- при движении без важной цели — смотрит в направление движения;
- в Waiting/Dialogue/WaitingForPackage/Receiving — смотрит на Player;
- при Leaving — снова ориентируется по locomotion;
- move target и look target могут отличаться;
- потеря/удаление look target безопасно возвращает gaze к movement/default;
- не должно быть прямых customer-specific вращений головы/корпуса в обход `CharacterLookSolver`.

### 5. Миграция Customer

`customer.tscn` должен стать NPC specialization общего character foundation.

Сохранить:
- `C_CustomerAgent`;
- `C_Health`, `C_Living`;
- `C_Interactable`, action set, direct handoff;
- Message/presentation hook, пока он нужен;
- current collision semantics для interaction/damage, с корректной миграцией layers/masks.

Перенести из `C_CustomerAgent` generic locomotion state (`destination/moving/arrived`), если после появления generic NPC component он становится дублирующим authority.

`CustomerMotionService` после миграции:
- удалить, если он больше не нужен; либо
- оставить только как временный adapter без ownership velocity, но финальное состояние R12.2 не должно иметь второго Customer-only locomotion path.

### 6. CustomerFlow integration

Customer-domain код продолжает решать **что NPC хочет сделать**, но не **как двигается физическое тело**.

Примеры:
- APPROACHING → установить move target = Waiting/Counter marker и look policy = movement;
- WAITING / DIALOGUE → stop movement, look target = Player;
- LEAVING → move target = Exit marker;
- AGGRESSIVE в рамках R12.2 только получает generic hook/target contract; pursuit/attack реализует R17.

`CustomerFlowService` не должен:
- писать body velocity;
- вызывать `move_and_slide`;
- менять body transform для обычной locomotion;
- зависеть от `CharacterBody3D` API.

### 7. Скорость и Customer definitions

Сейчас physics path читает `visit.definition.move_speed`, `arrival_distance` и `gravity`.

После R12.2:
- gravity управляется RigidBody/Jolt, Customer definition не является physics gravity authority;
- базовая скорость находится в `C_Motion.max_speed`/character config;
- customer-specific authored speed может при необходимости задавать generic NPC speed multiplier/config при spawn/phase setup;
- arrival distance является generic NPC target parameter;
- physics solver не делает lookup `CustomerVisit`.

Не оставлять две независимые настройки скорости, которые могут расходиться.

### 8. Navigation-ready, но без обязательного большого nav subsystem

R12.2 не обязана строить полноценный NavigationMesh/avoidance subsystem, если текущий warehouse flow использует короткие authored routes.

Но generic NPC contract должен позволять позже заменить direct target vector на путь:
- без изменения CustomerFlow;
- без изменения `CharacterMotionSolver`;
- без Customer-specific pathfinding API.

Если в ходе реализации обнаружится, что direct movement физически не может надёжно пройти текущий layout, допустимо добавить узкий NavigationAgent3D adapter как часть NPC layer.

### 9. Presentation / animation

Если текущая character model/library уже имеет подходящие Idle/Walk:
- NPC locomotion state должен переключать минимум Idle/Walk по реальной скорости тела;
- animation не становится источником transform/root motion;
- head look продолжает работать поверх locomotion animation.

Новые анимационные ассеты и сложная state machine вне scope.

## Критерии готовности

- Customer использует общий RigidBody character physics path, а не `CharacterBody3D + CustomerMotionService.move_and_slide()`.
- Player и Customer используют общие Motion/Look solvers, но разные producers intent.
- Customer остаётся полноценной GECS Entity и сохраняет весь текущий delivery/dialogue lifecycle.
- NPC можно дать world target и отдельный look target без знания customer subsystem.
- Коробка может физически остановить/сдвинуть Customer; внешний impulse не уничтожается locomotion solver на следующем кадре.
- Customer после безопасного физического отклонения способен продолжить движение к актуальной цели.
- Customer ожидает/разговаривает, глядя на Player, и уходит физически тем же actor body.
- Архитектура готова для R17: aggressive Customer сможет тем же NPC controller получить Player как pursuit/look target.
- Нет второго Customer-only movement/look/impact implementation.
- Player regression отсутствует.

## Проверки

### GUT
- NPC intent: target position -> корректные `direction_motion` / `direction_look`.
- Arrival threshold останавливает motion и выставляет arrived state.
- Move target и look target независимы.
- Invalid/deleted Entity target очищается безопасно.
- Player entity не обрабатывается NPC intent system.
- Customer phase -> generic NPC command mapping.
- Customer outcome/dialogue/direct-handoff tests продолжают проходить.

### Headless physics/integration
- Customer spawn -> approach -> wait -> leave на реальном RigidBody.
- Статическая/физическая коробка блокирует путь без teleport-through.
- Central impulse/impact сдвигает NPC; locomotion не обнуляет внешний импульс мгновенно.
- После смещения NPC продолжает движение к target.
- Customer death/removal корректно чистит runtime target state.
- Существующий customer-flow smoke остаётся зелёным после адаптации fixture.

### Player regression
- Focused character-contact physics smoke.
- Grab/Carry/Push/Cart surfaces только в объёме, который затронут scene split.
- Не запускать весь проект/test suite после каждого milestone; полный релевантный прогон — один раз ближе к завершению по `AGENTS.md`.

## Границы

В R12.2 не входят:
- полноценный combat/pursuit/attack AI — R17;
- crowd simulation, social groups, schedules вне CustomerFlow;
- сложный navmesh generation pipeline;
- NPC inventory/grab/tool use;
- jump/crouch для Customer;
- новый animation asset pack;
- глобальная reputation/perception логика.

## Первый шаг

1. Зафиксировать, какие components/nodes из `e_rigid_body_character.tscn` являются generic, а какие Player-only.
2. Выбрать scene split/inheritance без смены physics authority.
3. Спроектировать минимальный generic NPC intent component + `S_NpcIntent`.
4. Только после этого мигрировать `customer.tscn` и удалять `CustomerMotionService`.
