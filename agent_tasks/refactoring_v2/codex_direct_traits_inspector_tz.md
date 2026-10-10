# Codex Task — Direct Entity Traits в Godot Inspector

**Репозиторий:** `https://github.com/devrmbgames-jpg/Godot-PVZ-In-HELL`
**Ветка:** `dev`
**Статус:** `OWNER_QA`
**Файл прогресса:** этот файл (один источник; отдельный task не создаётся).
**Тип:** архитектурный UX-рефакторинг / миграция authoring-контракта.

## 1. Цель

## Task state

### Goal
Полная миграция на direct `traits` и постоянный стандартный Inspector, без legacy runtime path.

### Current

- Baseline SHA: `cb257c3469f4e05acba310199d93f0faee2db77a`, ветка `dev`.
- Прочитаны AGENTS и skills: refactoring, task-lifecycle, gdscript-style, gecs-v8,
  godot-scene-authoring, validation-workflow, gut-testing, review-orchestration, godot-ai-mcp,
  godot-performance.
- User override: старые сейвы не сохраняются, conversion не нужна; schema-10 new roundtrip обязателен.
- Аудит: 17 direct Entity classes в domains time/motion/hazards/combat/packages/interaction/customers;
  deeper NPC/player/package inheritance получает export автоматически. Compiler и factories общие.
- Mapping: metadata entity_composition → traits + definitions + bindings + ancestor_entity_bindings;
  Template nested Traits → самостоятельные authoring .tres; native raw Entity → E_TraitedEntity
  только при наличии Traits. IDs, физические узлы и остальные metadata сохраняются.
- Existing user edits сохранены в `.artifacts/direct_traits/user_baseline.patch`;
  открытые main_menu/box/authoring_level/dock сохранены через MCP, editor штатно закрыт.
- Implementation complete: E_TraitedEntity, direct compiler, persistent project-owned Inspector;
  28 migrated scenes, 11 extracted Trait resources. Mapping:
  `tests/fixtures/refactoring_v2/direct_traits_migration.json`; offline tool is editor-only/idempotent.
- EntityAuthoring runtime Resource/reader and session installer removed; dock is IDs/diagnostics only.
  Legacy Template resources remain editor-only presets, never production scene/runtime providers.
- Implementation checkpoint: `b2b6a80e6d8d347b5977e0ff2418b986bc09ec2b`.
- Current: implementation, automated acceptance and independent review/triage complete.
- Next: owner Inspector/gameplay checklist, then record acceptance; №42 stays OWNER_QA_PENDING.

### Validation
- GUT PASS: 225 tests / 1845 assertions, `.artifacts/direct_traits/gut_final.log`.
- Native headless Inspector PASS: add/new/type rejection/assign/reorder/remove/Make Unique,
  Undo/Redo, nested instance save/reopen, enable/disable/fallback/restart; `editor.log`.
- Final native harness PASS: 27 assertions, including reopened scene local copy and saved
  SceneState built-in settings, shared .tres protection and unchanged array/history;
  `editor_local_reopen.log`. Repair parser 2 files / 0 failures, formatter/static gates PASS.
- Parser PASS: 45 changed scripts / 0 failures. Formatter, strict architecture, agent gate PASS.
- Structure PASS after separately evidenced unused owner Theme rename (bytes/UID preserved,
  still untracked); [independent scope](../completed/developer_console_theme_naming.md).
- 5-scene baseline parity PASS: providers, per-field provenance, bindings, IDs and issues.
- Median of 3 × 500 box builds: baseline 232081 / new 242905 usec (+4.7%);
  registrations: 1969689 / 2036989 usec (+3.4%). Isolated same-engine/GECS checkout;
  no new runtime ticks; small pre-registration overhead reported, no gameplay hot-path change.
- night_persistence smoke PASS (write + fresh-process restore), district_package_receipts PASS.
  The runner now recognizes both existing `smoke PASS` and `smoke: PASS` completion delimiters.
- Logs/baseline patches/timings retained under `.artifacts/direct_traits/`; shutdown-only 4.7.1
  retention is KNOWN_ENGINE_LIMITATION / DEFERRED, not runtime regression evidence.
  Native functional assertions PASS; full editor shutdown is NOT_CLEAN (retention and existing
  harness detached-node path diagnostic category documented in №42), no clean-process claim.

### Review
- Base `cb257c3469f4e05acba310199d93f0faee2db77a` → target
  `b2b6a80e6d8d347b5977e0ff2418b986bc09ec2b`: independent source review collected.
- RV-001 (reviewer R1, P2): `_inspect` rejected saved local built-in resource paths (`scene::id`).
  FIXED `bde16943a1f20dae0f99d7f59d931953198f8855`: allow local-to-scene empty/built-in paths,
  keep shared .tres protected. Native evidence distinguishes empty-path instance copies from
  built-in saved SceneState resources; both open settings without copying. Harness 27/27 PASS.
- Targeted re-review: base `b2b6a80e6d8d347b5977e0ff2418b986bc09ec2b` → target
  `bde16943a1f20dae0f99d7f59d931953198f8855`, repair cycle 1/2; RV-001 resolved.
  No other substantial findings. Independent source architecture/style review PASS after triage;
  reviewer validation NOT_RUN, Main's actual checks above. Current review state PASS.
- Review efficiency telemetry: NOT_MEASURED (single substantive checkpoint).

### Owner QA / blockers
- Inspector ergonomics, actual resource picker/drag-drop, inherited scene editing and gameplay:
  OWNER_QA_PENDING; [owner checklist](../../qa_tasks/direct_entity_traits_inspector.md).
  No visual gameplay launch or visual PASS is claimed.

Разработчик выбирает Entity в дереве Godot и **непосредственно в стандартном Inspector** видит секцию **Gameplay Traits** и действие **Add Trait**. Он может добавить, выбрать, настроить, удалить или переставить Traits, не создавая вручную `DEF_EntityTemplate`, `EntityAuthoring` и `metadata/entity_composition`.

Новая конфигурация должна работать и для размещённых в `.tscn` Entity, и для runtime-spawned Entity. Существующие GECS, игровая логика, физика и сохранения остаются неизменными по поведению.

**Критерий удобства:** создать новую коробку/Entity, назначить существующий Trait, сохранить сцену и получить корректный компонент при регистрации — без отдельного дока, редактора metadata, ручного Template и нового скрипта на каждый объект.

## 2. Обязательная архитектура

1. Добавь проектный базовый класс `E_TraitedEntity extends Entity` в `content/shared/entities/e_traited_entity.gd` (или другой корректный по domain rules путь). `@tool`, `class_name`, **без `_process`, `_physics_process`, scheduler, runtime registry и автоматической регистрации**.
2. Экспортируй **`@export var traits: Array[EntityTrait] = []`** непосредственно на Entity; поле доступно стандартному Inspector даже при выключенном кастомном плагине.
3. Не называй этот класс `EntityTrait`: это имя уже принадлежит `Resource`-классу `content/shared/authoring/entity_trait.gd`. Не путай его с игровыми особенностями NPC `DEF_NpcTrait`.
4. Переведи **project-owned прямые наследники `Entity`**, для которых корректно это наследование, на `E_TraitedEntity`; более глубокие наследники получают экспорт автоматически. Предварительно проинвентаризируй наследование и фактические scene scripts. Не редактируй `addons/gecs/` и не трогай узлы, которые не являются GECS Entity.
5. Entity без Traits работает как раньше: нулевой список допустим, `component_resources`, `define_components`, `id`, `World.add_entity`, сигналы и прочие методы GECS сохраняются. Непосредственный `Entity` из GECS тоже остаётся допустимым для объектов без Traits. Для raw Entity со Traits назначай проектный скрипт явно.
6. **Единственный источник authored Traits в runtime — экспортированное поле `traits`**. Не оставляй постоянного второго пути через `metadata/entity_composition`/`EntityAuthoring`/Template. Временный миграционный адаптер допустим только до завершения этой задачи.
7. Сложным Entity сохрани входные `definitions`, именованные `bindings`, `ancestor_entity_bindings` через **явные типизированные экспортированные поля базового класса либо другой равно прозрачный прямой контракт**. Расположи их в сворачиваемой **Advanced Authoring** группе; у простого объекта они пусты, дополнительный Resource не нужен. Не меняй семантику NodePath и nearest ancestor Entity.
8. `DEF_EntityTemplate` допустим как **необязательный editor-only preset** для повторного заполнения списка Traits. Он не должен быть обязательной runtime-ссылкой или вторым источником истины. Извлеки переиспользуемые вложенные Traits из старых Templates в самостоятельные `.tres` там, где это необходимо для корректной миграции.

## 3. Единая компиляция и lifecycle

1. Сохрани один общий `EntityBuildRules` / `EntityCompositionService` и один `EntityBuildPlan`. Адаптируй компиляцию к прямому массиву `traits`; нет отдельной реализации для Inspector, placed и factory.
2. Смешивай существующие `component_resources`, `define_components` и Traits по прежним правилам: **один владелец каждого Component Script**, явный отказ при duplicate provider, проверка зависимостей, initial fields и bindings. Никакого silent override / «последний побеждает».
3. Сохрани детерминированность порядка, чистое построение плана без gameplay side effects, отдельные копии mutable Component/records/arrays для каждого Entity и общие ссылки только на immutable Definitions/assets.
4. Сохрани контракты `registration_plan` / `register_plan`, whole-set validation, корректное назначение IDs, сохранённые state overlays, `RegistrationScope`, ready barrier и отсутствие преждевременных Observer/System-реакций. Физические pose/velocity остаются за Godot/Jolt.
5. **Нет проверок Traits каждый кадр и повторной «починки» компонентов после регистрации**. Валидация при authoring и перед регистрацией — по необходимости. Не добавляй второй валидатор, глобальный cache/registry, новую систему ECS или тяжёлое копирование на hot path. Не удаляй safety-checks ради скорости без доказательства эквивалентности.
6. `EntityTrait` остаётся декларативным ресурсом (recipes/configuration/requirements), а не runtime-состоянием. `DEF_NpcTrait` и `S_NpcTraits` не рефакторить этой задачей.

## 4. Inspector UX — основной результат

Реализуй штатный project-owned `EditorPlugin` + `EditorInspectorPlugin` / `EditorProperty` для `E_TraitedEntity` в **обычном Inspector Godot 4.7.1**, не подменяя весь Inspector.

- Секция **Gameplay Traits** видна сразу при выборе объекта, без отдельной команды или запуска `EditorScript`.
- Видимый список назначенных Traits: понятное имя/`trait_id`, ресурс и возможность открыть его настройки.
- Кнопка **Add Trait**: выбор существующего `.tres` (с проверкой, что ресурс — `EntityTrait`), и **New Trait** для допустимого нового ресурса. Действие не требует создать Template.
- **Remove**, порядок элементов, native drag/drop ресурсов (если поддержано штатно); порядок в UI не должен менять семантику провайдеров.
- Все правки создают **Undo/Redo**, помечают сцену изменённой и переживают save/reopen, inherited scene и prefab instance. Не меняют общий `.tres` при настройке только одного экземпляра без явного `Make Unique`/локальной копии.
- Показывай простые ошибки возле Traits: дубликат, missing dependency, incompatible root/node, missing binding. Подробный provider provenance и диагностический отчёт доступны через **Advanced**.
- `Validate Scene Composition` использует **тот же компилятор** через detached preview, без `_ready`, World publication, AI, физического шага или gameplay effect.
- Реализуй обычный **постоянный editor plugin** (`plugin.cfg`, включение через Project Settings → Plugins; проверить корректное восстановление после перезапуска). Старый разовый `install_entity_authoring.gd` не должен требоваться для базового использования.
- Сохрани удобное управление **Instance ID / Level ID**, но не заставляй открывать отдельный док ради Traits. Если док оставлен для диагностики/ID, он не должен дублировать редактируемый список Traits.
- Если плагин отключён или сломан, **нативное экспортированное поле `traits` всё ещё редактируется** обычным Inspector.

## 5. Миграция контента — обязательна, не отложена

1. До изменений составь inventory: project-owned классы `extends Entity`, сцены и вложенные префабы с `metadata/entity_composition`, `EntityAuthoring`, `DEF_EntityTemplate`, их Traits, Profiles, Bindings, instance/local/world IDs и места создания через фабрики. Сохрани mapping old → new в текущем task-файле кратко или в отдельной migration fixture.
2. Мигрируй **все реально используемые** scene/template конфигурации на прямое поле `traits`. Включая физические персонажи, `box.tscn`, `physical_slot.tscn`, district NPC/trader/customer, package/hazard и затронутые fixture-сцены. Для scene roots с проектным наследованием используй `E_TraitedEntity`; не меняй тип физического Node.
3. Перенеси `definitions`, `bindings`, `ancestor_entity_bindings` в новые явные поля с прежними именами endpoint и прежней семантикой. Если Trait был вложенным `SubResource` в Template, извлеки/скопируй его **без потери конфигурации, ссылок на Definitions и разделения между экземплярами**; учитывай существующие ресурсы и варианты NPC.
4. После миграции **никакая production-сцена не требует** `metadata/entity_composition`. Удали устаревшие runtime-readers, дубль панелей/инсталляторов и неиспользуемые legacy resources только после проверки ссылок. Сами `persistent_local_id`, `persistent_world_id` и иные metadata, нужные сохранениям/редактору, **сохрани**: запрещено удалять metadata вообще.
5. Не переписывай IDs, `uid://`, сцены, script paths, exported значения, узлы, физические формы, сигналы и связанные ресурсы без необходимости. **Текущий save schema 10 и фактическое поведение загрузки/restore обязаны сохраниться**; существующие сейвы должны загружаться.
6. Убери постоянное двойное чтение old+new формата и независимые runtime-пути к концу задачи. Если migration tooling нужно, сделай его явным, повторно запускаемым и **editor/offline-only**, не на каждом запуске игры.
7. Работа с открытыми сценами — через редактор/MCP по правилам `AGENTS.md`; не перетирай несохранённые изменения и не выполняй слепую замену `.tscn`/`.tres`.

## 6. Проверки и acceptance

**Проверить автоматически:**

- Pure `Entity` и `E_TraitedEntity` с пустым `traits` продолжают работать; обычный `component_resources` путь не сломан.
- Простая сцена: прямое назначение `et_impact_capture.tres` без Template/metadata → `C_ImpactInbox` после ровно одной регистрации.
- Неизменность сформированных Components/Relationships для representative migrated scenes (до/после), включая NPC Profiles/merchant, package, physical slot, named/ancestor bindings, scene `define_components`.
- Duplicate Traits/Component providers, missing requirements, invalid fields/endpoints/IDs отвергаются до side effects; конфликт не исправляется молча.
- Mutable nested state уникально для двух spawned Entity; общий immutable Profile не копируется и не мутируется.
- Placed и spawned parity; registration once, ready barrier, saved overlay, persistence schema-10 roundtrip, отсутствие смены identity/ownership; отмена ошибочного spawn не оставляет зарегистрированных Entity.
- Native Inspector: add/remove/assign/reorder, Undo/Redo, save/reload, inherited/nested scenes и экземпляры; plugin enable/disable и повторный запуск редактора; native `traits` fallback без плагина.
- Никаких новых `_process`/`_physics_process`, service ticks, двойной системной регистрации и runtime-чтения **legacy authored** `metadata/entity_composition`/Templates. Внутренние lifecycle-маркеры `_entity_recipes_prepared` и `_entity_composition_ready` не удалять без эквивалентной проверенной замены.

**Инструменты:** Godot `.bin/` (parser/headless), GUT и existing smoke tests; адаптировать `tests/gut/test_entity_build_rules.gd`, `test_entity_authoring_preview.gd`, `test_entity_recipe_isolation.gd`, другие затронутые test fixtures и editor harness. Проверить `main_level.tscn`, минимальный новый prefab, один placed и один spawned сценарий. Замерить compile/registration baseline vs new на representative mass-spawn; не вводить регрессий без отчёта.

**Owner QA:** фактическая удобность кнопки, внешний вид Inspector, выбор ресурсов, редактирование внутри наследуемой сцены и gameplay feel — `OWNER_QA_PENDING` до моей ручной проверки. Не выдавать headless тесты за визуальный PASS.

**Done только если:** созданному объекту Trait назначается в обычном Inspector за несколько действий; сцена работает без Template/authoring metadata; все задействованные существующие сцены мигрированы; GECS, physical state и сохранения не сломаны; static/parser/GUT/smoke проверки пройдены, review findings закрыты либо явно триажированы. Не оставлять permanent legacy dual-path.

## 7. Порядок выполнения Codex

1. Прочитай `AGENTS.md` и **только необходимые** `.agents/skills/`: `refactoring`, `gecs-v8`, `gdscript-style`, `godot-scene-authoring`, `task-lifecycle`, `validation-workflow`, `gut-testing`; при существенном milestone также `review-orchestration`. Не загружай всё дерево документации.
2. Зафиксируй краткий baseline, inventory и план. Веди текущее состояние в `agent_tasks/direct_entity_traits_authoring.md` по `agent_tasks/README.md` (один источник прогресса; обновляй `Current/Next`, не раздувай журнал).
3. Выполняй этапы: **базовый класс и прямой контракт → единый compiler → Inspector plugin → миграция сцен → full regression и review**. Каждый законченный логический этап — отдельный commit. Не оставляй остановленную наполовину миграцию под статусом DONE.
4. Не используй GitHub CLI (`gh`), не изменяй third-party addons, не переключайся на `master`, не делай push/PR/merge без отдельного запроса. Сохраняй чужие uncommitted edits.
5. Можешь самостоятельно запускать Godot headless/parser, GUT, корректировать тестовую оснастку и недостающие editor tools. **Не запускай rendered gameplay и не утверждай visual QA без моего разрешения.** Субагенты, если нужны, работают последовательно.
6. Сверься с незавершённой задачей `agent_tasks/refactoring_v2/42_visual_entity_authoring.md`: её требования по stable IDs, безопасному preview и owner QA сохраняются; пересечение scope документируй, но не отмечай №42 завершённой без фактического Owner QA.
7. На финале дай: что изменено; перечисление migrated scenes; как теперь добавить Trait (3–5 шагов); удалённые legacy пути; фактически выполненные тесты; реальные ограничения; пункты Owner QA. Проверка shutdown-only resource/RID retention Godot 4.7.1 остаётся известным ограничением, не поводом отвлекаться от задачи (см. `AGENTS.md`).

## Ссылки на существующую реализацию

- `content/shared/authoring/entity_trait.gd`
- `content/shared/authoring/entity_authoring.gd`
- `content/shared/definitions/def_entity_template.gd`
- `content/shared/services/entity_composition_service.gd`
- `content/shared/rules/entity_build_rules.gd`
- `content/editor/entity_authoring/*`
- `docs/entity_authoring.md`
- `agent_tasks/completed/refactoring_v2/41_entity_templates_traits.md`
- `agent_tasks/refactoring_v2/42_visual_entity_authoring.md`
- Godot 4.7 Inspector plugins: https://docs.godotengine.org/en/4.7/tutorials/plugins/editor/inspector_plugins.html
