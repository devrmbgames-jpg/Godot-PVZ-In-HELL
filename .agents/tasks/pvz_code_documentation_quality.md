# PVZ-DOC01 — Качество документирования проектного GDScript

Status: **PLANNED**
Priority: **P2** (задача по выбранному замечанию о документации кода)
Baseline: `dev` / `6aac58da7f03943aa62614ee3dbb1ad317747748`

## Goal

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

- [ ] Все действующие first-party scripts в scope учтены; omissions и исключения имеют конкретное обоснование, а не общий legacy allowlist.
- [ ] У каждого скрипта есть полезное описание; exports/signals/public mutable fields задокументированы без пустых шаблонов и пересказа имени.
- [ ] У каждого нетривиального публичного boundary понятны owner, preconditions, mutation, return/rejection и момент завершения; async/reentrant boundaries не маскируются под синхронные.
- [ ] Derived cache, authoritative state, immutable authoring и terminal history различаются; units, time domain и lifetime constraints указаны там, где они влияют на корректность использования.
- [ ] Комментарии соответствуют фактическому коду после PVZ-A01/A02/B01/CAL01, а persistence explanations — актуальному документу PVZ-A03.
- [ ] Между base/target нет скрытого изменения runtime semantics, публичных symbols и сохранённых/авторских контрактов в documentation-only batches.
- [ ] Зафиксированы проверенный scope и фактические counts; нет выдуманного «100% качества» по наличию ## или проценту comment lines.
- [ ] Завершающий reviewer проверил критические public APIs и репрезентативные файлы каждой обработанной группы; оставшиеся проблемы устранены либо задача остаётся незавершённой.

## Validation

Использовать существующие style tools или небольшой scoped inventory/check при отсутствии нужной проверки; не строить новую тяжёлую documentation framework. Структурная проверка должна учитывать annotations/multiline/inner classes; отсутствие ## можно обнаруживать автоматически, истинность и достаточность комментария проверяет человек/reviewer.

Проверить diff/сравнение некомментных GDScript tokens, чтобы documentation-only batches не меняли код; regex-filter сам по себе не доказательство semantic equivalence. Запустить scoped formatter check и native parser затронутых `.gd` после связного batch, плюс link/symbol validation. Обычный полный GUT/gameplay прогон для одних комментариев не нужен; изменившийся исполняемый пример/helper требует своего focused теста.

Финальная проверка распространяется на все изменённые файлы относительно полного base SHA, а не на пустой `--changed` после коммита. Не утверждать, что процент structural coverage доказывает смысловую полноту. Исходные engine/runtime gates предыдущих задач не заменяются этим documentation pass.

## Task state

### Current
ТЗ подготовлено. Полный inventory/метрики ещё не сняты; исправление документации и финальный review: **NOT_RUN**.

### Next
Получить актуальный first-party inventory и начать M1. Комментарии неизменяемых областей можно исправлять независимо, но финальный M3 выполнить на совместном результате задач ниже.

### Dependencies
Финальная сверка после [PVZ-A01](pvz_a01_commerce_panel_scene_first.md), [PVZ-CAL01](pvz_customers_calendar_fact_ownership.md), [PVZ-A02](pvz_a02_wallet_day_events.md), [PVZ-B01](pvz_b01_configfile_save_storage.md), [PVZ-A03](pvz_a03_persistence_documentation.md). Каждая implementation задача документирует свой новый код сразу; эта задача не разрешает откладывать такую документацию.

### Completion
Следовать [AGENTS.md](../../AGENTS.md) и task-lifecycle: GitHub Actions/gh, внешние addon edits и неразрешённые visual tests запрещены; не более одного child agent одновременно. Хранить здесь полные base/target/review/fix SHA, краткие фактические counts, PASS/FAIL/NOT_RUN и текущие unresolved findings; без отдельной очереди/истории. После полного scope, проверок и review — DONE и перенос этого же файла в `completed/` с исправлением ссылок.
