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

Текущий третий batch: EntityCompositionService, ObserverReactionBoundary, CommandBufferBarrier, EntityBuildPlan, GameWorld, GrabPhysicsSolver, C_Autosave, AutosaveStore, SnapshotRestoreBoundary, WorldSnapshotService, SaveDataCodec. Уточнены synchronous registration/queued flush, borrowed physics context, codec/preflight/partial mutation, restore readiness и autosave writers. Всего изменены 27 уникальных scripts; полный M1/M2/M3 и quality pass остальных файлов не завершены.

Current batch base: `7698e2b45962a1c6a483df5dfbe2309b5b24b4dc` → target `e0055c870e65f339ed9079f58b7d24fbdfd52ee3`. Initial read-only review **FAIL**: одна неточность timing, RV-001 ниже. Public symbols/defaults/exports/SAVE_FIELDS не меняются.

RV-001 (R1), P2, **ACCEPTED**: RegistrationScope.finish/register_plan ошибочно описывали initial commands как обязательно pending. Pinned GECS gitlink `14d4282e5c1cb2713c187706ba2f5ff4e315d36e`, `_invoke_entry` исполняет PER_CALLBACK inline. Текст уточнён: inline effects/reentrancy возможны, extra global drain отсутствует; оставшаяся MANUAL/deferred работа принадлежит caller flush. Fix/targeted re-review **PENDING**, cycle 1/2.

Проверки batch:

- PASS: `verify_gdscript_nonbehavior_changes.py --base 7698e2b45962a1c6a483df5dfbe2309b5b24b4dc --mode comments` — 11 scripts, 0 отличий executable source/strings/indentation.
- PASS: GDQuest incremental format/lint — 11 scripts; native `ParseChanged`, `.artifacts/godot_agent/parsechanged-20261015-174249722.stdout.log` / `.stderr.log`.
- PASS: live MCP `pvz_gdscript_path_diagnostics` — все 11 paths checked, diagnostics empty, no instantiation. `script_patch` fallback reload 43 не принят за PASS; после него path compile/CLI parser PASS, editor log просмотрен (новых релевантных ошибок нет).
- PASS: incremental agent validator, strict architecture (0 lexical findings), project structure, scoped whitespace.
- Full GUT/gameplay/visual: **NOT_RUN**, для comment-only batch не нужны; visual budget 0/8.

В editor log обнаружен существующий отдельный parse defect `personal_delivery_dialogue_smoke.gd:173`: can_see получал DEF_NpcArchetype вместо NpcRecord. В отдельном [SMOKE-PD01](completed/personal_delivery_smoke_perception_argument.md) исправлен единственный аргумент: native parse и двухпроцессный smoke PASS, review PASS, implementation `45ddf2e8bfbd4cb83a40c0bdee27621a106aae88`. DOC01 batch этот код не менял. Cyclic authoring resource errors принадлежат намеренно некорректным test fixtures; сообщения не объявляются общим editor PASS.

### Next
Завершить fix commit/targeted re-review RV-001. Независимо прочитаны все 11 inventory, 15 time и 21 commerce scripts; найденные documentation уточнения ещё не внесены и требуют отдельного batch. E_PhysicalCharacter/E_PhysicalSlot описывают authored glue корректно. Остальные first-party файлы остаются открытым scope. `verify_gdscript_nonbehavior_changes.py` сохраняет strings/indentation; собственные addons проверять тем же scanner явно из-за CLI skip. Финальный M3 — на совместном результате зависимостей.

### Dependencies
Финальная сверка после [PVZ-A01](pvz_a01_commerce_panel_scene_first.md), [PVZ-CAL01](completed/pvz_customers_calendar_fact_ownership.md), [PVZ-A02](completed/pvz_a02_wallet_day_events.md), [PVZ-B01](pvz_b01_configfile_save_storage.md), [PVZ-A03](completed/pvz_a03_persistence_documentation.md). Каждая implementation задача документирует свой новый код сразу; эта задача не разрешает откладывать такую документацию.

### Owner QA / blockers

### Completion
Следовать [AGENTS.md](../../AGENTS.md) и task-lifecycle: GitHub Actions/gh, внешние addon edits и неразрешённые visual tests запрещены; не более одного child agent одновременно. Хранить здесь полные base/target/review/fix SHA, краткие фактические counts, PASS/FAIL/NOT_RUN и текущие unresolved findings; без отдельной очереди/истории. После полного scope, проверок и review — DONE и перенос этого же файла в `completed/` с исправлением ссылок.
