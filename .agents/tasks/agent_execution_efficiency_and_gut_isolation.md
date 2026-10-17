# AGENT-PERF01 — ускорение автономной разработки и изоляция GUT-тестов

Status: **PLANNED**
Technical: **NOT_STARTED**
Execution order: **15**
Reference baseline: `4c8a846f288fc2d0aa2296089bcb3bc517206630` (dev, 2026-10-17).

## Goal / acceptance

Устранить подтверждённые лишние GUT-прогоны и уменьшить повторные переделки при
автономной реализации игровых механик. Не сокращать игровую приёмку и не превращать
ускорение в новые обязательные отчёты, согласования или глобальные тестовые запуски.

Результат:
1. Самостоятельный запуск конкретного GUT-файла выполняет его собственные `test_*`,
   а не унаследованные тесты соседних подсистем; прежние проверки доступны отдельными
   наборами и не потеряны. Общая подготовка переиспользуется без наследования test suites.
2. Перед **существенной** игровой реализацией агент применяет короткий contract preflight:
   игровой результат, state owner, неизменяемые гарантии потребителей, реальные
   provider-зависимости, исключения и проверка результата. Мелкие fixes не получают новый gate.
3. Неожиданное разрастание затрагиваемых подсистем вызывает локальный scope triage:
   использовать имеющийся контракт / минимально расширить необходимый provider /
   выделить самостоятельный evidenced дефект; не переписывать соседние системы «на будущее».
4. На 2–3 репрезентативных checkpoint получены реальные, ограниченные по стоимости
   измерения времени и повторных проверок; результат/недоступность данных зафиксированы
   без выдуманного «ускорения в N раз».

## Current / confirmed baseline

- **Реализация этого ТЗ не начата.** Здесь результаты анализа исходников, не отметки
  о выполненной новой native validation.
- Цепочка `test_pvz_tool_orders.gd` (5 собственных тестов) → `test_hag_direct_shop.gd`
  (9) → `test_buyback_lifecycle.gd` (15) → `test_npc_life_cycle.gd` (9) →
  `test_npc_authored_population.gd` (7): потенциально 45 test methods при выборе
  5 тестов инструментов ПВЗ из-за наследования конкретных suites.
- `test_crafting_lifecycle.gd` (15) наследует buyback/lifecycle/population:
  потенциально 46 test methods вместо 15. Фактические native totals и elapsed
  подтвердить на доступной среде, не считать подсчёт исходников измерением времени.
- В [торговой задаче](district_resident_barter_and_buyback.md) ревью T2a/T3a/T3b
  исправляло уже известные гарантии: frozen crafting plan, постоянную личность
  торговца и сохранность старого ассортимента. Это основание для preflight,
  **не** доказательство конкретного расхода часов агентом.
- Уже существуют [modular-gameplay-design](../skills/modular-gameplay-design/SKILL.md),
  [validation-workflow](../skills/validation-workflow/SKILL.md) и
  [review-orchestration](../skills/review-orchestration/SKILL.md); новый параллельный
  процесс или переписывание `AGENTS.md` не требуются.
- [Runner-классификация](completed/godot_validation_result_classification.md) завершена;
  отсутствие доказанной изоляции ECS/save/physics не позволяет объявить универсальный
  batch-run оптимизацией. Текущую shutdown-only engine policy не пересматривать.

## Work packages / проверяемые результаты

| Пакет | Что сделать | Acceptance |
| --- | --- | --- |
| E1 — audit | Зафиксировать фактическую цепочку `extends`, собственные/унаследованные tests, существующие fixture hooks и baseline elapsed на доступном Godot. Найти аналогичные конкретные test-suite chains в `tests/gut/`, не сканировать весь репозиторий без необходимости. | Список затронутых suites и измеренный baseline либо явный NOT_MEASURED; сохранённые test names/инварианты. |
| E2 — fixture isolation | Для обнаруженных commerce/NPC цепочек вынести общий setup/teardown в небольшие composable helpers под `tests/helpers/` либо в base fixture **без** `test_*`. Каждый самостоятельный тестовый класс наследует `GutTest`, а не другой рабочий `test_*.gd`. | Точечный запуск PVZ tools исполняет его 5 собственных тестов, crafting — 15; исходные NPC, buyback и Hag suites доступны отдельно; все прежние checks проходят. |
| E3 — contract preflight | В существующем [modular-gameplay-design](../skills/modular-gameplay-design/SKILL.md) уточнить только при необходимости краткий preflight *до кода* для крупных игровых пакетов; в [gut-testing](../skills/gut-testing/SKILL.md) закрепить запрет наследовать concrete test suites. Никаких новых обязательных документов. | Существующий working plan/task позволяет найти owner, frozen guarantees, touched consumers, exclusions, focused checks; мелкие fixes не требуют отдельного плана. |
| E4 — scope control | Проверить на следующей значимой механике, что неожиданный выход за state-owner boundaries разбирается по существующему modular skill. Указать минимальный provider change и первого реального consumer; не создавать второй authority. | Есть конкретный пример triage: локальное расширение или мотивированная зависимость/отдельная задача; при отсутствии такого случая — NOT_OBSERVED, без искусственной переделки. |
| E5 — bounded measurement | Снять показатели для E2 и ещё 1–2 следующих доступных существенных checkpoint (всего 2–3), включая сравнение GUT до/после на сопоставимом наборе. Завершить пилот краткими выводами и NO_CHANGE, где дальнейшая автоматизация не окупается. | Таблица actual измерений и источников; отсутствующие величины — NOT_MEASURED, повторы тестов не выполнены ради статистики. |

## Implementation constraints / critical contracts

- Изменять только тестовую инфраструктуру, узкие относящиеся скиллы и необходимый
  локальный validation guard. Не рефакторить production GECS, commerce, NPC, save
  или сцены ради переиспользования тестов. Реальный независимый defect оформить в
  своём owning task с воспроизведением, не присваивать его этому ускорению.
- Сохранить исходные имена и смысл test cases, `before_each/after_each`, async
  ожидания, `ECS.world`, native World/Entity lifecycle, сигналы и очистку `user://`
  файлов. Не превращать реальные интеграционные проверки в mock-only green.
- Helpers не владеют игровым состоянием; не вводить общий mutable singleton, который
  загрязняет другой тест. Не добавлять abstract framework или «универсальный»
  runner без доказанной необходимости. Изолировать тестовые данные/Resource mutations.
- Точечная проверка одного нового сценария — свой suite. Если изменён общий provider,
  проверить его затронутые consumer suites отдельно один раз перед checkpoint;
  не дублировать все родительские тесты при каждом вызове.
- Не вводить фиксированный предел файлов или систем как блокирующее правило:
  сигналом к scope triage служат чужой state owner, конкурирующее authority,
  непредусмотренная миграция либо отклонение от заявленного игрового поведения.
- Не менять `AGENTS.md`, task-manager архитектуру, статусы соседних задач,
  Godot/GUT версию, сторонние `addons/` или GitHub Actions. Main — единственный
  writer; reviewers проверяют immutable SHA; не запускать rendered QA.

## Verification / evidence protocol

1. Для E2 сохранить до/после фактические **числа test cases и elapsed** по
   `test_pvz_tool_orders.gd`, `test_crafting_lifecycle.gd`, отдельно
   `test_hag_direct_shop.gd`, `test_buyback_lifecycle.gd`,
   `test_npc_life_cycle.gd`, `test_npc_authored_population.gd`.
   Проверить не только суммарный PASS, но и что каждый прежний `test_*` по-прежнему
   выполняется в своём suite. При недоступном runner — NOT_RUN, не подменять static PASS.
2. Показать отсутствие test-suite inheritance в исправленных цепочках (например
   точечным source check) и сохранность setup/teardown и save cleanup; при необходимости
   добавить маленький guard в существующую проверку, не создавать дорогой full-scan.
3. После одного логически цельного изменения выполнить focused native GUT, актуальные
   `utils/validate_agent_changes.py`, architecture/structure checks и formatter
   согласно [validation-workflow](../skills/validation-workflow/SKILL.md).
   Повторять только проваленные/затронутые guarantees. Парсер/статический анализ
   не заменяют настоящий Godot.
4. Для 2–3 checkpoint записать: `BASE_SHA..TARGET_SHA`, собственные/фактически
   запущенные tests, GUT elapsed и число запусков, длительность main implementation,
   review/repair и tool troubleshooting **только если доступны реальные timestamps**,
   количество принятых findings и repair cycles. Отмечать overlap, неизвестные
   величины `NOT_MEASURED` и условность сравнения. Не требовать platform token usage.
5. Хранить **одну компактную текущую сводку пилота здесь** и ссылки на штатные
   result manifests/logs в `tests/artifacts/` или `.artifacts/`; не плодить
   ежедневные журналы, дубли задач, daemon, автоматические watchers, CI или
   отдельные менеджерские очереди.
6. По завершении E2/E3 — coherent commit и read-only exact-SHA review/triage;
   E4/E5 допускается проверить на следующих разрешённых checkpoints без задержки
   независимых игровых задач. Не объявлять всё ТЗ DONE до обязательных evidence.

## Entry points / dependencies

- `tests/gut/test_npc_authored_population.gd`,
  `test_npc_life_cycle.gd`, `test_buyback_lifecycle.gd`,
  `test_hag_direct_shop.gd`, `test_pvz_tool_orders.gd`,
  `test_crafting_lifecycle.gd`; `tests/helpers/`.
- `utils/godot_agent.ps1`, `utils/godot_agent.md`,
  [gut-testing](../skills/gut-testing/SKILL.md),
  [modular-gameplay-design](../skills/modular-gameplay-design/SKILL.md),
  [task-lifecycle](../skills/task-lifecycle/SKILL.md),
  [task README](README.md). Не дублировать завершённую runner-задачу.
- Это вспомогательный пакет, **не prerequisite** всего gameplay backlog.
  Уже начатую безопасную работу не прерывать в середине checkpoint. После
  технических изменений продолжать независимые задачи автономно.

## Next

E1: снять inventory/базовые native числа и проанализировать hooks указанных
GUT-chain файлов. Затем E2 → E3; при следующих релевантных checkpoint выполнить
E4/E5 без дополнительных согласований в пределах действующей политики.

## Validation / review

ТЗ создано как план: implementation, native GUT, timing pilot, review — **NOT_RUN**.
Для docs-only создания проверять структуру task/ссылки и отсутствие изменения
исходного gameplay scope; Godot запускать только при выполнении реализации.

## Owner QA / blockers

Rendered/visual QA не нужна; ручная gameplay QA прежних игровых задач остаётся
в их собственных карточках. Не обещать конкретного процента ускорения без измерений.
Если доступного Godot/таймингов/подходящих новых checkpoint нет, записать точный
недоступный gate и продолжать независимые задачи; не изобретать фиктивные результаты.
