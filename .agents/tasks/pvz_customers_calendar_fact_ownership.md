# PVZ-CAL01 — Customers не публикует чужой календарный факт

Status: **PLANNED**
Priority: **P2** (локальный идентификатор задачи для выбранного замечания аудита)
Baseline: `dev` / `6aac58da7f03943aa62614ee3dbb1ad317747748`

## Goal

Убрать использование DayPhaseChanged как скрытой команды восстановления Customers. Реальный календарный факт публикует владелец календарного перехода; инициализация/сверка планирования имеет отдельный явный путь.

## Evidence / scope

- [s_customer_flow.gd](../../content/domains/customers/systems/s_customer_flow.gd), `_advance()`: несовпадение planning_day/planning_phase вызывает `_world.emit_event(DayPhaseChanged.EVENT, ...)` без изменения календаря.
- [o_customer_planning.gd](../../content/domains/customers/observers/o_customer_planning.gd): `_prepare_session()` уже проверяет контекст и идемпотентность; прямое доказательство двойных визитов аудитом не получено. Исправляется семантика границы, а не объявленная воспроизведённой ошибка начисления.
- [customer_planning_request.gd](../../content/domains/customers/contracts/customer_planning_request.gd): существующие команды и terminal receipt. [s_day_phase.gd](../../content/domains/time/systems/s_day_phase.gd): реальный producer DayPhaseChanged.
- Scope: указанные owners, producer/consumer данного события, startup/restore composition, необходимые manifests и целевые тесты. Механики появления клиентов, календарь и баланс не перепроектировать.

## Required approach

1. Прочитать [GECS v8](../skills/gecs-v8/SKILL.md), [GDScript style](../skills/gdscript-style/SKILL.md), [refactoring](../skills/refactoring/SKILL.md), [validation](../skills/validation-workflow/SKILL.md). На актуальном HEAD найти все реальные публикации/подписки DayPhaseChanged, не ограничиваясь строковым поиском одного файла.
2. Оставить production-публикацию DayPhaseChanged у `S_DayPhase._publish_phase()` после committed mutation. Bootstrap/restore, повторный вход в уровень и добавление customer capability не должны выдавать сверку за произошедший календарный переход. Не менять смысл общего события на replay/snapshot для обхода этого требования.
3. Переиспользовать CustomerPlanningRequest/O_CustomerPlanning. При необходимости добавить один конкретный вид команды для reconcile актуального календарного контекста; не создавать второй planning owner, универсальный event bus или сервисный scheduler.
4. Явно связать запрос со startup/ready и завершением passive restore. Сохранить поддержку отсутствующего district, однократного позднего появления capability и нового World в тестах. Обычное изменение фазы обрабатывается уже существующим календарным фактом.
5. Удалить повторную публикацию из S_CustomerFlow. Не заменять её покадровым безусловным emit локальной команды. Допустим узкий одноразовый/dirty recovery check: одна команда на конкретную пару aggregate+generation+day/phase, без повторного enqueue до receipt; обычный tick продолжает владеть своими arrival clocks/history.
6. Общую операцию подготовки переиспользовать без вызовов одной System/Observer как чужого imperative helper. O_CustomerPlanning остаётся реактивным владельцем; узкая синхронная операция допустима, скрытый service tick — нет.
7. Для queued runtime запроса захватывать WeakRef владельца и точные Components/day/phase/generation. Проверять stale context в owning callback; исчезновение/замена владельца завершает receipt отказом, а не оставляет вечный pending. Null-owner допустим только для уже оговорённых изолированных data fixtures.
8. Соблюдать timing GECS: submit/emit не означает completed. Зафиксировать точку flush, после которой consumers могут читать planning markers. PER_CALLBACK и отложенный режим должны приводить к одинаковому результату без повторных визитов, штрафов и цепочек reentrant вызовов.
9. Обновить необходимые domain contracts, документацию producer/request/fact и callers в одной миграции. Не добавлять allowlist или постоянный legacy путь.

## Acceptance / focused regressions

- [ ] Event-spy: bootstrap и reconcile Customers не публикуют DayPhaseChanged и не вызывают посторонних календарных подписчиков.
- [ ] Реальный Morning → Day → Evening → Night переход публикует соответствующий факт после mutation; наблюдатель видит committed day/phase.
- [ ] Startup и safe restore готовят клиентов один раз, без default-state gameplay effects в passive construction.
- [ ] Повторная команда/reconcile для того же контекста не дублирует визиты, registration-overdue penalties, followups и подготовку delivery offers.
- [ ] Пока receipt pending, последующие ticks не создают поток одинаковых команд; после отказа восстановление возможно только для актуального контекста.
- [ ] Замена Component/World, удаление owner или смена календаря до flush безопасно отклоняют старую команду и завершают её receipt.
- [ ] Работают стандартный PER_CALLBACK и действительно отложенный flush; нет синхронного ожидания очереди, бесконечной рекурсии и выдачи enqueue за completion.
- [ ] Arrival cooldown/history и подготовка утра перед Night capture сохраняют прежнюю семантику.

## Validation

Расширить ближайшие существующие GUT для CustomerPlanning/CustomerFlow/DayPhase; новый небольшой suite нужен только если подходящего нет. После связного изменения выполнить focused native GUT, parser изменённых файлов и один startup → phase transition → Night/restore non-visual сценарий на milestone.

Запустить formatter, structure/domain dependency и strict architecture gates по validation-workflow; проверить production producers DayPhaseChanged. Не запрещать тестовым fixtures публиковать моделируемые факты. Сохранить точный producer contract в тесте, а не только lint по имени метода.

## Task state

### Current
ТЗ подготовлено; исходный риск подтверждён чтением кода. Реализация/engine regressions/review исправления: **NOT_RUN**.

### Next
Инвентаризировать publishers/subscribers и текущие startup/restore точки; выбрать минимальный явный reconcile request и его flush/receipt contract.

### Dependencies
Выполнить перед [PVZ-A02: кошелёк](pvz_a02_wallet_day_events.md). ConfigFile migration может выполняться независимо, но перед общей приёмкой повторно проверить startup/Night интеграцию. Итоговые контракты сверяются в задачах [PVZ-A03](pvz_a03_persistence_documentation.md) и [документирования кода](pvz_code_documentation_quality.md).

### Completion / exclusions
Не включать NPC neighbour optimization, threat-clock decomposition и новый gameplay. Следовать [AGENTS.md](../../AGENTS.md) и [task lifecycle](../skills/task-lifecycle/SKILL.md); GitHub Actions/gh и неразрешённые visual playtests не запускать. Проверять связные этапы, не каждую мелкую правку. Полные base/target/review/fix SHA и текущие PASS/FAIL/NOT_RUN хранить здесь; не более одного child agent одновременно. DONE только после необходимых проверок/review; затем перенести исходный файл в `completed/` с исправлением ссылок.
