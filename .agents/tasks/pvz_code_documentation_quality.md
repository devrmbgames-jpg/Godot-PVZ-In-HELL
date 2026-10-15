# PVZ-DOC01 — Качество документирования проектного GDScript

Status: **IN_PROGRESS**
Priority: **P2** (задача по выбранному замечанию о документации кода)
Baseline: `dev` / `6aac58da7f03943aa62614ee3dbb1ad317747748`

## Task state

### Goal

Устранить пропуски, неточности и бесполезные комментарии в проектном коде так, чтобы разработчик понимал назначение, владельца состояния, единицы, ограничения и timing публичной операции без реконструкции всего call graph. Не увеличивать количество комментариев ради процента покрытия и не менять игровое поведение.

## Baseline / scope

Аудит исследовал выборку, а не всё дерево; исходный процент покрытия неизвестен. Хорошие образцы уже существуют: [R_HeldBy](../../content/domains/interaction/relationships/r_held_by.gd), [C_NpcDecision](../../content/domains/npc/components/c_npc_decision.gd), [DEF_NpcArchetype](../../content/domains/npc/definitions/def_npc_archetype.gd), [WalletService](../../content/domains/commerce/services/wallet_service.gd). Их комментарии не следует механически переписывать.

Scope — все действующие first-party production/tool `.gd`, определённые по актуальному tracked inventory: `content/**` (все домены, shared, scenes, UI, debug), `utils/**`, собственные `addons/project_entity_traits/**` и `addons/pvz_ai_tools/**`, а также реально найденные другие проектные скрипты. Внешние addons, submodules, `.godot`, экспортные/сгенерированные копии и архивные backups исключаются. Тесты учитывать отдельно; изменённые публичные fixtures/helpers документировать по их контракту, а не требовать описаний каждого очевидного test_*.

Это явный широкий documentation pass: выполнить весь согласованный first-party scope небольшими domain batches. Не закрывать задачу после одной выборки или изменения только AGENTS/skills. Дефекты поведения, обнаруженные при чтении, фиксировать отдельными задачами, не скрывать изменением комментария.

## Required approach

1. Прочитать [GDScript style](../skills/gdscript-style/SKILL.md), [GECS](../skills/gecs-v8/SKILL.md), [validation](../skills/validation-workflow/SKILL.md), [task lifecycle](../skills/task-lifecycle/SKILL.md). Для нетривиальных ссылок/lifetime использовать extended guidance по необходимости.
2. До правок получить воспроизводимый список tracked `.gd`, уточнить first-party ownership/exclusions и фактические количества по доменам. Отдельно учесть скрипты без class_name, многострочные @export/declarations, вложенные классы и inherited API. Нельзя считать весь addons сторонним или весь addons проектным.
3. Для каждого скрипта обеспечить краткое корректное `##` назначение и границу ответственности. Не повторять class_name другими словами. Для engine/editor glue указать связь с callback/сценой и почему код находится вне scheduled System.
4. Документировать все exports, signals и public mutable fields: смысл, единицы/система координат/clock domain, допустимые значения и обязательность. Для runtime state обозначить writer; для derived cache — source и invalidation/rebuild; для immutable Definition — отсутствие runtime mutation; для Relationship — владение и очистку endpoint.
5. Для неочевидного public метода описать preconditions, изменяемое состояние, return/rejection semantics, idempotency и completion timing. Ясно различать accepted/pending/dispatched и committed/completed; указать receipt/event и flush point. Очевидному accessor не нужен комментарий, пересказывающий имя.
6. На queued/deferred/reentrant границах объяснять WeakRef, captured Component identity/generation и условие отказа. Не добавлять обычным synchronous invariant вызовам фиктивную nullable-семантику и не удалять необходимые guards как «шум».
7. Private nontrivial алгоритмы пояснять короткими комментариями о причине, порядке фаз и ограничениях. Использовать логичные `#region` главы, не region на каждый метод. Удалять устаревшие/ложные комментарии и очевидные пересказы кода; сохранить полезные объяснения компромиссов.
8. Сначала обработать public/domain/async границы: save/load/ConfigFile, календарь и Customers, wallet/transactions, damage, inventory/ownership, physical callbacks, composition/Traits. Затем пройти остальные first-party файлы по доменам и global/tooling scope. Проверить новые файлы предыдущих задач на финальном HEAD.
9. Не переименовывать C_/R_/S_/O_/E_/DEF_/ET_/UI_ ради линтера; не делать public поля private лишь для сокращения документации. Не менять типы, defaults, exports, signals, SAVE_FIELDS, NodePaths, execution order и gameplay semantics в documentation-only commit. Не переводить весь проект на другой язык механически; новые формулировки делать понятными и согласованными с соседним API.
10. Общие принципы оставить в skills/ARCHITECTURE, предметные контракты — в профильных docs, локальное поведение — возле API. Не копировать длинный архитектурный документ в каждый файл. Если роли/действующий код расходятся с пожеланием, описать факт честно и отдельно зарегистрировать дефект.

## Milestones

### M1 — Inventory и критические контракты
Снять scope/базовые метрики; завершить документацию критических boundaries и исправления ложной семантики accepted/completed, writer/cache/lifetime. Повторно используемые примеры — реальные APIs проекта, не вымышленные.

### M2 — Полный first-party pass
Пройти остальные production/tool скрипты небольшими связными domain batches. Для каждого batch обновлять здесь только актуальные Current/Next и итог проверки; не накапливать журнал чтения/правок. Незакрытые файлы остаются видимыми, scope не сужается молча.

### M3 — Сверка и закрытие
После завершения связанных исправлений переснять inventory, проверить новые/удалённые файлы и междокументные противоречия. Выдать итог по реальным file/declaration counts, нарушениям и точечным обоснованным исключениям. Машинный structural coverage и ручная оценка смысла — разные результаты.

## Acceptance

- [x] Все действующие first-party scripts в scope учтены; exclusions определены tracked inventory и явным ownership, не общим legacy allowlist.
- [ ] У каждого скрипта есть полезное описание; exports/signals/public mutable fields задокументированы без пустых шаблонов и пересказа имени.
- [ ] У каждого нетривиального публичного boundary понятны owner, preconditions, mutation, return/rejection и момент завершения; async/reentrant boundaries не маскируются под синхронные.
- [ ] Derived cache, authoritative state, immutable authoring и terminal history различаются; units, time domain и lifetime constraints указаны там, где они влияют на корректность использования.
- [ ] Комментарии соответствуют фактическому коду после PVZ-A01/A02/B01/CAL01, а persistence explanations — актуальному документу PVZ-A03.
- [ ] Между base/target нет скрытого изменения runtime semantics, публичных symbols и сохранённых/авторских контрактов в documentation-only batches.
- [ ] Зафиксированы проверенный scope и фактические counts; нет выдуманного «100% качества» по наличию ## или проценту comment lines.
- [ ] Завершающий reviewer проверил критические public APIs и репрезентативные файлы каждой обработанной группы; оставшиеся проблемы устранены либо задача остаётся незавершённой.

### Validation

Использовать существующие style tools или небольшой scoped inventory/check при отсутствии нужной проверки; не строить новую тяжёлую documentation framework. Структурная проверка должна учитывать annotations/multiline/inner classes; отсутствие ## можно обнаруживать автоматически, истинность и достаточность комментария проверяет человек/reviewer.

Проверить diff/сравнение некомментных GDScript tokens, чтобы documentation-only batches не меняли код; regex-filter сам по себе не доказательство semantic equivalence. Запустить scoped formatter check и native parser затронутых `.gd` после связного batch, плюс link/symbol validation. Обычный полный GUT/gameplay прогон для одних комментариев не нужен; изменившийся исполняемый пример/helper требует своего focused теста.

Финальная проверка распространяется на все изменённые файлы относительно полного base SHA, а не на пустой `--changed` после коммита. Не утверждать, что процент structural coverage доказывает смысловую полноту. Исходные engine/runtime gates предыдущих задач не заменяются этим documentation pass.


### Current
M1 inventory снят на `45e71fe4010f147ff18a21818c0c2162afcbf20f` через `git ls-files -z -- '*.gd'`: 1603 tracked scripts, из них 947 first-party production/tool, 236 tests, 420 внешних addon scripts. Других корней `.gd` не найдено. `addons/gecs` — отдельный submodule, не входит в tracked first-party scope и не изменяется. Scope не сокращён до первых просмотренных APIs.

| Группа | Scripts |
| --- | ---: |
| challenges | 28 |
| combat | 78 |
| commerce | 21 |
| customers | 113 |
| hazards | 44 |
| interaction | 153 |
| inventory | 11 |
| motion | 22 |
| needs | 7 |
| npc | 225 |
| packages | 70 |
| persistence | 19 |
| quests | 10 |
| time | 15 |
| content/shared | 31 |
| content/scenes | 6 |
| content/ui | 31 |
| content/debug | 19 |
| content/editor | 11 |
| utils | 16 |
| addons/project_entity_traits | 1 |
| addons/pvz_ai_tools | 16 |

На pinned inventory baseline 67501 строк и 158 scripts без class_name. Native inventory на `77328491ce8d3ebc183888165f135925f83c2f73` нашёл **11 inner classes в 9 scripts**; ранний lexical count 2 scripts был неверен и заменён native данными. Это структурные метрики, не оценка качества. `.artifacts/doc01_inventory.json` сохраняет воспроизводимый список выбранных путей; источник scope — tracked Git inventory и явные root exclusions выше. Простой поиск `##` до class_name дал ложный пропуск E_Door (описание стоит после class_name); такой regex не используется как acceptance gate.

Native `Script` metadata для всех 947 first-party paths: **1109 declared exported fields**, **1874 declared public mutable fields** (exports входят в это число, если имя public), **28 declared signals**, **1647 distinct declared public methods**; дополнительно 11 inner classes включены в declaration totals. У 499 scripts есть script base. Reflection включает inherited members, поэтому properties/signals base вычтены, методы сопоставлены с собственными class-scope declarations и дедуплицированы по имени; synthetic setter methods исключены. Native metadata обрабатывает annotations/multiline, а inner classes разрешены через Script constant map. Public static var declarations не обнаружены. Смысл комментариев и inherited contract каждого consumer остаются предметом ручного pass.

Evidence: disposable `.artifacts/doc01_native_inventory.gd` → `.artifacts/doc01_native_declarations.json`, logs `.artifacts/godot_agent/doc01-native-inventory.stdout.log` / `.stderr.log`: 947 scripts, failed 0, native exit 0, stderr пустой. Нет script.new/instance creation, authored scene/resource writes или runtime ticks. Первоначальный probe с неправильным Variant cast отброшен; итоговый запуск имеет явный type guard. Контрольные случаи C_DayCycle (13 собственных полей вместо inherited parent), E_Door (inherited exports/methods/signals отдельно), EntityBuildPlan (2 inner classes) и MaterialGeneratorController проверены вручную. Эти числа не являются «процентом качества».

Inventory record review: **PASS**, base `77328491ce8d3ebc183888165f135925f83c2f73` → target `71dd93cb6c4fffe3fd6f15b30580212bdf2b3427`, no material findings; reviewer эмпирические counts не воспроизводил, только immutable claims/methodology review.

M1, проверенный первый code batch: C_DayCycle, DayTransitionRequest, DayPhaseService, S_DayPhase, GameTimeRules, C_CustomerFlow, CustomerFlowService и WalletService. Accepted запрос / committed факт, gameplay seconds/ticks, writers/кеш, WeakRef receipt lifetime и sync wallet commit уточнены. Base `8d38ada79fe25d4cc03290ca99996788bb3d93b5` → target `e81cf30fb763435a16c33ea88f695b5b4ea7e767`, read-only review **PASS**, material findings нет, triage завершён. Parser log `parsechanged-20261015-172123537`, nonbehavior 8/0, formatter/MCP/static PASS.

Проверенный второй batch: DamageRequest, DamageResult, DamageRequestService, HealthMutationService, C_Inventory, C_InventoryItem, R_OwnedBy, InventoryService. Уточнены dispatch/completion, HP/range constraints, transient use correlation, transfer/drop guards и delayed healing. Base `71dd93cb6c4fffe3fd6f15b30580212bdf2b3427` → target `5d4d81edc05e4affff71e2f1adb092dcd0421229`, read-only review **PASS**, material findings нет, triage завершён. Parser log `parsechanged-20261015-173513516`, nonbehavior 8/0, formatter/MCP/static PASS.

Проверенный третий batch: EntityCompositionService, ObserverReactionBoundary, CommandBufferBarrier, EntityBuildPlan, GameWorld, GrabPhysicsSolver, C_Autosave, AutosaveStore, SnapshotRestoreBoundary, WorldSnapshotService, SaveDataCodec. Уточнены registration/flush, borrowed physics context, codec/preflight/partial mutation, restore readiness и autosave writers; review/fix evidence ниже.

Третий checkpoint: base `7698e2b45962a1c6a483df5dfbe2309b5b24b4dc` → target `e0055c870e65f339ed9079f58b7d24fbdfd52ee3`; reviewed fix `41b55b0558a11479513fba9c58044c0132c8f6e6`. Final review **PASS**, RV-001 исправлен. Public symbols/defaults/exports/SAVE_FIELDS не меняются.

RV-001 (R1), P2, **FIXED** (`41b55b0558a11479513fba9c58044c0132c8f6e6`): RegistrationScope.finish/register_plan ошибочно описывали initial commands как обязательно pending. Pinned GECS `14d4282e5c1cb2713c187706ba2f5ff4e315d36e`, `_invoke_entry` исполняет PER_CALLBACK inline. Уточнены inline effects/reentrancy, отсутствие extra global drain и caller flush оставшейся MANUAL/deferred работы. Targeted read-only re-review base `e0055c870e65f339ed9079f58b7d24fbdfd52ee3` → fix target выше: **PASS**, cycle 1/2, новых findings нет. Fix formatter/nonbehavior/native CLI parser/MCP compile — 2 paths PASS; parser log `parsechanged-20261015-174712450`.

Проверенный четвёртый batch — полный source pass: **inventory 11/11, time 15/15, commerce 21/21 — PASS**. Прочитаны все 47 scripts, включая не требующие изменений; декларации сверены с поведением/callers. Исправлены комментарии 25 новых scripts: writers/caches/units, immutable authoring, payment versus fulfillment, body/pickup lifetime и transient IDs. Reviewer проверил changed claims и representative unchanged O_InventoryLifecycle/GameTimeQueries/TraderCatalogRules; RV-002 исправлен и targeted re-review PASS.

Четвёртый checkpoint: base `198ccf8dbb75a6e2ec0813949281fbee73b87561` → target `05a02d86c9e667644bcc2db49c74aba8f6620141`, reviewed fix `1ce357a96936cc255c1162cb6f8315b14cdcfa67`; final review **PASS**. Остальные domain/global/tool groups проверяются отдельными batches.

RV-002 (R1 четвёртого batch), P2, **FIXED** (`1ce357a96936cc255c1162cb6f8315b14cdcfa67`): NightPreparationRequirement ошибочно называл любой queued reply поздним. Уточнена граница возврата emit_event: native PER_CALLBACK может успеть, MANUAL/later flush опоздает. Targeted read-only re-review base `05a02d86c9e667644bcc2db49c74aba8f6620141` → fix target: **PASS**, cycle 1/2, новых findings нет. Format/nonbehavior/native ParseFiles/MCP — 1 path PASS; parser log `parsefiles-20261015-175453107`.

Проверенный пятый batch — полный source pass **needs 7/7, quests 10/10, challenges 28/28 — PASS**. Прочитаны все 45 scripts и необходимые writers/callers; 26 scripts получили уточнения owners, gameplay units, transient/cache versus durable history, Relationship cleanup и outcome/reward timing. Reviewer сверил changed claims и representative unchanged HungerRules, RefusalQuestValidator, condition Systems и lifecycle/consequence Observers; material findings нет, triage завершён.

Пятый checkpoint: base `1c51aa2b457bfdf5c3f0a452d4ead33005b655e4` → target `2bc9d1119d76c2e8c0e596caa6337b06d85a4960`; read-only review **PASS**, новых findings нет. Nonbehavior/format/native parser/MCP — 26 paths PASS, parser log `parsechanged-20261015-175908161`.

Проверенный шестой batch — полный source pass **motion 22/22 — PASS**. Прочитаны все scripts, authored Physics/Input groups и writers контактных данных из combat. Уточнены 13 scripts: приём прыжка versus применение импульса, gameplay versus physics delta, восстановление stamina, накопление/потребление импульсов, контактные кеши и неиспользуемое legacy look_direction. Reviewer сверил changed claims, routing delta и representative unchanged owners; material findings нет, triage завершён.

Шестой checkpoint: base `057ce606964138d081792826a137d769e951a28c` → target `da976c51b656157ef7ebe8359e87e1e4c0d78758`; read-only review **PASS**, новых findings нет. Format/nonbehavior/native parser/MCP — 13 paths PASS. `ParseChanged` wrapper FAIL только из-за shutdown retention (67 ObjectDB / 45 resources), **KNOWN_ENGINE_LIMITATION / DEFERRED**; logs `parsechanged-20261015-180622967` сохранены. Script_patch C_Jump generic reload 43 не объявлялся PASS; независимые CLI parser/MCP compile прошли.

Проверенный седьмой batch — полный source pass **shared 31/31, scenes 6/6 — PASS**. Прочитаны все 37 scripts и точечные callers; 18 scripts получили уточнения per-Component notification scope, domain-owned validation, identity priority, compiler/template gate, placement cache/reservation и deferred scene transition. Reviewer сверил changed claims и representative unchanged EntityTrait/EntityInitialBinding/EntitySpawnContext/EntityBuildPlan; material findings нет, triage завершён.

Седьмой checkpoint: base `72eef7fd960e9b4a2b5ece41c6cc333dd103d47a` → target `1caaf26dc2722957fa28110960470977473c17f8`; read-only review **PASS**, новых findings нет. Format/nonbehavior/native parser/MCP — 18 paths PASS; parser log `parsechanged-20261015-181153934`, stderr пустой.

Проверенный восьмой batch — полный source pass **persistence 19/19 — PASS**. Прочитаны все scripts; 12 получили уточнения receipt writers, deferred startup reconciliation, explicit Night reset/quiescence, structural preconditions, detached prefab probes и native body reconstruction. Reviewer сверил changed claims и representative unchanged codec/store/WorldSnapshot/restore boundaries; material findings нет, triage завершён.

Восьмой checkpoint: base `8aa6aaf12e597719e47935c4791fef1a06706a0e` → target `8c608f6b218a8de915cf5d2d3b0544999f5c86e1`; read-only review **PASS**, новых findings нет. Format/nonbehavior/native parser/MCP — 12 paths PASS; parser log `parsechanged-20261015-181721058`, stderr пустой.

Проверенный девятый batch — полный source pass **packages 70/70 — PASS**. Прочитаны все scripts и clocks authored GamePlay; 45 scripts получили уточнения writers, borrowed/consumed Nodes, command dispatch/terminal receipts, partial cargo commits, departure lifetime, event timing и transient versus durable state. Reviewer сверил changed claims и representative unchanged action/fact/Trait/presentation contracts; material findings нет, triage завершён.

Девятый checkpoint: base `0bd1a3bb07d31b12bdd10be1e5a5d33f28ee1862` → target `cbff99b2406a7218721fc40270590f733c3d72f9`; review **PASS**, новых findings нет.

Десятый batch: полный source pass **debug 19/19 — PASS**, уточнены 14 scripts: значение success, shared targets, inline dispatch, wallet units, QA placement/reset, isolated save и destructive debug lifecycle. Base `229753cf92572354f5f3be803ff7d6cd931f43c5` → target `442e15a99a0a5b28dd693a430344cf8dff554a08`, reviewed fix `876ce9da314a28d0781778ddf619a5620465e72b`; final review **PASS**, triage завершён. RV-003 (R1), P2, **FIXED**: исправление разделяет Node deletion и strong Resource references/membership. Targeted re-review base `442e15a99a0a5b28dd693a430344cf8dff554a08` → fix target PASS, cycle 1/2; formatter/nonbehavior/native parser/MCP — 1 path PASS, log `parsefiles-20261015-185550821`. В documentation-only batches изменены 180 уникальных scripts; двенадцать полных групп (259 scripts) имеют review PASS. М1/М2/М3 целиком не завершены.

Проверки batch:

- PASS: `verify_gdscript_nonbehavior_changes.py --base 229753cf92572354f5f3be803ff7d6cd931f43c5 --mode comments` — 14 scripts, 0 отличий executable source/strings/indentation; GDQuest incremental format/lint — 14 scripts.
- PASS: native `ParseChanged` — 14 files, 0 failures, process exit 0; logs `.artifacts/godot_agent/parsechanged-20261015-185223470.stdout.log` / `.stderr.log`, stderr пустой. Предыдущий packages parser `parsechanged-20261015-182820273` (45 paths) и final C_LiquidTilt `parsefiles-20261015-182958706` — PASS.
- PASS: live MCP `pvz_gdscript_path_diagnostics` — все 14 paths checked, diagnostics empty, scripts_instantiated=0.
- PASS: incremental agent validator, strict architecture (0 lexical findings), project structure, scoped whitespace.
- Full GUT/gameplay/visual: **NOT_RUN**, для comment-only batch не нужны; visual budget 0/8.

В editor log обнаружен существующий отдельный parse defect `personal_delivery_dialogue_smoke.gd:173`: can_see получал DEF_NpcArchetype вместо NpcRecord. В отдельном [SMOKE-PD01](completed/personal_delivery_smoke_perception_argument.md) исправлен единственный аргумент: native parse и двухпроцессный smoke PASS, review PASS, implementation `45ddf2e8bfbd4cb83a40c0bdee27621a106aae88`. DOC01 batch этот код не менял. Cyclic authoring resource errors принадлежат намеренно некорректным test fixtures; сообщения не объявляются общим editor PASS.

Одиннадцатый batch: полный source pass **editor 11/11 — PASS**, уточнены 5 scripts: disposable root ownership/configuration, сохраняемые shared assets, dictionary keys, scan reset/report validity и synchronous preview worker. Base `39368bd8b67436bbcdfbcb17d56ddfc236d2a462` → target `a0c95f376f294ab8bc1a9daa76097701f43fdc07`; read-only review **PASS**, material findings нет, triage завершён. Format/nonbehavior — 5 paths PASS; native parser 5/0, exit 0, stderr пустой, log `parsechanged-20261015-185614519`; MCP 5 checked/empty, no instantiation. Strict architecture 0 findings и structure PASS; incremental agent validator применимых production paths не нашёл (0), это не дополнительная проверка editor-кода. Scoped whitespace PASS. GUT/gameplay/visual NOT_RUN, comments-only; budget 0/8. Изменены 185 уникальных doc scripts; 13 полных групп (270 scripts) имеют review PASS.

### Next

Текущий двенадцатый batch: полный source pass utils 16/16, уточнены 9 scripts: local/world units, непосредственные editor mutations, async source lifetime, partial saves, import warnings и CPU timings. Base `821d5223245ed9e640c7f008f86b933bada0164b`; target после commit, review **REVIEW_PENDING**, не DONE. Format/nonbehavior9/0 PASS; native parser9/0, exit0/stderr пустой, log `parsechanged-20261015-190017674`; live MCP9 checked/empty, scripts_instantiated=0. Strict architecture/structure/whitespace PASS; incremental agent validator0 применимых paths. GUT/gameplay/visual NOT_RUN, comment-only, budget0/8. Изменены194 уникальных doc scripts, review PASS у13 полных групп (270 scripts); utils ждёт review.

Закончить utils review. Независимые [QA-CMP01](debug_complaint_pending_message.md) и выделенный lifecycle scope [QA-GLTF01](gltf_import_variant_node_cleanup.md) проверяются отдельно. [QA-SAVE01](completed/debug_save_slot_full_preflight.md) и [QA-HP01](completed/debug_health_receipt_before_dispatch.md) завершены, review PASS; focused GUT после обоих10/10. Behavior fixes не входят в comment-only count. PVZH1 storage остаётся по owner fallback; ConfigFile migration не возобновляется. Собственные addons проверять nonbehavior scanner явно из-за CLI skip. Финальный M3 — на совместном результате зависимостей.

### Dependencies
Финальная сверка после [PVZ-A01](pvz_a01_commerce_panel_scene_first.md), [PVZ-CAL01](completed/pvz_customers_calendar_fact_ownership.md), [PVZ-A02](completed/pvz_a02_wallet_day_events.md), [PVZ-B01](pvz_b01_configfile_save_storage.md), [PVZ-A03](completed/pvz_a03_persistence_documentation.md). Каждая implementation задача документирует свой новый код сразу; эта задача не разрешает откладывать такую документацию.

### Owner QA / blockers

### Completion
Следовать [AGENTS.md](../../AGENTS.md) и task-lifecycle: GitHub Actions/gh, внешние addon edits и неразрешённые visual tests запрещены; не более одного child agent одновременно. Хранить здесь полные base/target/review/fix SHA, краткие фактические counts, PASS/FAIL/NOT_RUN и текущие unresolved findings; без отдельной очереди/истории. После полного scope, проверок и review — DONE и перенос этого же файла в `completed/` с исправлением ссылок.
