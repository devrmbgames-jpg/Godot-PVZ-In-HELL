# PVZ-A02 — Итоги кошелька по событиям, без покадрового polling

Status: **PLANNED**
Priority: **P2**
Baseline: `dev` / `6aac58da7f03943aa62614ee3dbb1ad317747748`
Dependency: [PVZ-CAL01](pvz_customers_calendar_fact_ownership.md)

## Task state

### Goal

Заменить регулярный обход S_WalletDay реакцией на committed календарный переход и явной однократной инициализацией/сверкой. Сохранить финансовые результаты и идемпотентность; не менять экономику.

## Evidence / scope

- [s_wallet_day.gd](../../content/domains/commerce/systems/s_wallet_day.gd): `process()` каждый проход целиком делегирует работу `WalletService.sync_day()`.
- [wallet_service.gd](../../content/domains/commerce/services/wallet_service.gd): `sync_day()` создаёт daily result и через shift_completed однократно учитывает Evening/Night. Двойной зачёт аудитом не доказан; исправляется execution ownership.
- [s_day_phase.gd](../../content/domains/time/systems/s_day_phase.gd) уже публикует DayPhaseChanged. [s_night_save.gd](../../content/domains/persistence/systems/s_night_save.gd) содержит зависимость от S_WalletDay.
- Scope: commerce owner, регистрация Systems/Observers в production и fixtures, startup/restore boundary, затронутые deps/manifests, тесты кошелька и Night snapshot.

## Required approach

1. Прочитать [GECS v8](../skills/gecs-v8/SKILL.md), [GDScript style](../skills/gdscript-style/SKILL.md), [validation](../skills/validation-workflow/SKILL.md). Перепроверить код на актуальном HEAD и сначала закрыть PVZ-CAL01, чтобы новый consumer не зависел от ложных календарных публикаций.
2. Ввести commerce-owned Observer, например `O_WalletDay`, реагирующий на DayPhaseChanged у сессии с C_Wallet/C_DayCycle. Зарегистрировать его в действующей composition, включая тестовые Worlds. Не создавать UI System, второй wallet aggregate или новый календарный scheduler.
3. Оставить одну узкую идемпотентную операцию кошелька для `ensure current daily result / record shift completion`. WalletService вправе выполнять синхронную операцию, но не владеть периодикой. Существующее имя sync_day можно сохранить лишь при ясном новом контракте; переименование не является исправлением само по себе.
4. Явно вызвать инициализацию/сверку при новом World и после успешного passive restore, когда авторитетные данные готовы. Не публиковать синтетический DayPhaseChanged. Учесть session без операций, восстановленные Morning/Evening/Night и предусмотренное позднее добавление wallet capability.
5. Сохранить создание daily result, начальный/closing balance, shift_completed, completed_days и смысл операций/settlement IDs. Первый платёж до явной инициализации и повторная инициализация должны давать тот же результат. Не добавлять второй флаг «день обработан», когда существует authoritative shift_completed.
6. Установить commit/flush boundary: Night capture и последующие consumers читают завершённые итоги, а не pending enqueue. Обработчик использует captured event day/phase и проверяет актуальность владельца/Components при queued исполнении; stale событие не закрывает другой день.
7. Удалить S_WalletDay и все действующие регистрации/ссылки на него, включая `S_NightSave.deps()`, scene resources, tests и актуальные manifests. Исторические completed tasks не переписывать. Не сохранять no-op System, alias, forwarding wrapper или новый service tick.
8. Обновить комментарии timing/idempotency и ближайшую документацию. Формат сохранения не менять только ради смены execution owner: новые persistable поля здесь не требуются.

## Acceptance / focused regressions

- [ ] В production нет регулярного S_WalletDay и покадрового вызова wallet day reconciliation.
- [ ] Новый день без единой операции получает корректный daily result; операция до/после bootstrap не меняет итог и не создаёт дубль.
- [ ] Morning/Day сами по себе не увеличивают completed_days; Evening закрывает смену один раз, последующий Night — не второй раз.
- [ ] Повторный факт/инициализация не меняют balance, penalties, income/spending, shift_completed и completed_days повторно.
- [ ] Новый день создаёт отдельный результат с правильным closing balance; восстановленные данные не обнуляются и не пересчитываются как новые.
- [ ] Stale day/phase, замена wallet/cycle, смена World или удаление владельца до flush не меняют чужое состояние.
- [ ] После перехода/flush Night snapshot содержит актуальные результаты; повторная запись Night не закрывает смену снова.
- [ ] Для обычного и отложенного buffer режима результат совпадает; bootstrap Customers не запускает wallet day reaction.

### Validation

Расширить существующие focused GUT кошелька/календаря сценариями выше; не дублировать уже достаточные тесты. Native parser изменённых scripts/scenes; один non-visual календарь → итог → Night snapshot/restore smoke на завершении этапа.

Применить formatter, structure/domain dependencies и strict architecture gates по validation-workflow. Добавить узкую регрессию против возврата `System.process → Service.sync_day` или эквивалентного polling; текущий regex tick/update/process его не ловит. Не превращать это в запрет всех Service-вызовов из Systems и не добавлять allowlist скрытого scheduler.


### Current
ТЗ подготовлено. Реализация, engine проверки и review исправления: **NOT_RUN**.

### Next
После PVZ-CAL01 определить фактические bootstrap/restore и Night flush точки, затем перенести дискретное владение в commerce Observer.

### Dependencies / exclusions
Не изменять тарифы, причины MoneyOperation, settlement rules, покупки и scope прочих доменов. [ConfigFile migration](pvz_b01_configfile_save_storage.md) независима, но итоговый тест Night выполнить на совместном результате. [PVZ-A03](pvz_a03_persistence_documentation.md) фиксирует окончательный контракт; [documentation quality](pvz_code_documentation_quality.md) выполняет завершающую сверку.

### Owner QA / blockers

### Completion
Соблюдать [AGENTS.md](../../AGENTS.md), [task lifecycle](../skills/task-lifecycle/SKILL.md), non-visual ограничения и последовательных child agents. GitHub Actions/gh не запускать. Проверки выполнять после связных изменений, не каждого edit. Внести полные base/target/review/fix SHA, реальные PASS/FAIL/NOT_RUN и нерешённые замечания сюда. DONE — только после необходимой валидации/review; затем переместить этот же файл в `completed/` и исправить ссылки.
