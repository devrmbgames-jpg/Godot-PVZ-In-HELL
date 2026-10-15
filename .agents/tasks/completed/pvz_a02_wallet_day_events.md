# PVZ-A02 — Итоги кошелька по событиям, без покадрового polling

Status: **DONE**
Priority: **P2**
BASE_SHA: `78d016bd200db8b12d7c9e7f14cb1c72995494b6`
TARGET_SHA: `729c345b8df96426916129504e8654d97ca60437`
Dependency: [PVZ-CAL01](pvz_customers_calendar_fact_ownership.md)

## Task state

### Goal

Заменить регулярный обход S_WalletDay реакцией на committed календарный переход и явной однократной инициализацией/сверкой. Сохранить финансовые результаты и идемпотентность; не менять экономику.

## Evidence / scope

- На исходном checkpoint `S_WalletDay.process()` каждый проход делегировал работу `WalletService.sync_day()`. Текущий владелец — [o_wallet_day.gd](../../../content/domains/commerce/observers/o_wallet_day.gd); старый System удалён.
- [wallet_service.gd](../../../content/domains/commerce/services/wallet_service.gd): `sync_day()` создаёт daily result и через shift_completed однократно учитывает Evening/Night. Двойной зачёт аудитом не доказан; исправляется execution ownership.
- [s_day_phase.gd](../../../content/domains/time/systems/s_day_phase.gd) уже публикует DayPhaseChanged. [s_night_save.gd](../../../content/domains/persistence/systems/s_night_save.gd) содержит зависимость от S_WalletDay.
- Scope: commerce owner, регистрация Systems/Observers в production и fixtures, startup/restore boundary, затронутые deps/manifests, тесты кошелька и Night snapshot.

## Required approach

1. Прочитать [GECS v8](../../skills/gecs-v8/SKILL.md), [GDScript style](../../skills/gdscript-style/SKILL.md), [validation](../../skills/validation-workflow/SKILL.md). Перепроверить код на актуальном HEAD и сначала закрыть PVZ-CAL01, чтобы новый consumer не зависел от ложных календарных публикаций.
2. Ввести commerce-owned Observer, например `O_WalletDay`, реагирующий на DayPhaseChanged у сессии с C_Wallet/C_DayCycle. Зарегистрировать его в действующей composition, включая тестовые Worlds. Не создавать UI System, второй wallet aggregate или новый календарный scheduler.
3. Оставить одну узкую идемпотентную операцию кошелька для `ensure current daily result / record shift completion`. WalletService вправе выполнять синхронную операцию, но не владеть периодикой. Существующее имя sync_day можно сохранить лишь при ясном новом контракте; переименование не является исправлением само по себе.
4. Явно вызвать инициализацию/сверку при новом World и после успешного passive restore, когда авторитетные данные готовы. Не публиковать синтетический DayPhaseChanged. Учесть session без операций, восстановленные Morning/Evening/Night и предусмотренное позднее добавление wallet capability.
5. Сохранить создание daily result, начальный/closing balance, shift_completed, completed_days и смысл операций/settlement IDs. Первый платёж до явной инициализации и повторная инициализация должны давать тот же результат. Не добавлять второй флаг «день обработан», когда существует authoritative shift_completed.
6. Установить commit/flush boundary: Night capture и последующие consumers читают завершённые итоги, а не pending enqueue. Обработчик использует captured event day/phase и проверяет актуальность владельца/Components при queued исполнении; stale событие не закрывает другой день.
7. Удалить S_WalletDay и все действующие регистрации/ссылки на него, включая `S_NightSave.deps()`, scene resources, tests и актуальные manifests. Исторические completed tasks не переписывать. Не сохранять no-op System, alias, forwarding wrapper или новый service tick.
8. Обновить комментарии timing/idempotency и ближайшую документацию. Формат сохранения не менять только ради смены execution owner: новые persistable поля здесь не требуются.

## Acceptance / focused regressions

- [x] В production нет регулярного S_WalletDay и покадрового вызова wallet day reconciliation.
- [x] Новый день без единой операции получает корректный daily result; операция до/после bootstrap не меняет итог и не создаёт дубль.
- [x] Morning/Day сами по себе не увеличивают completed_days; Evening закрывает смену один раз, последующий Night — не второй раз.
- [x] Повторный факт/инициализация не меняют balance, penalties, income/spending, shift_completed и completed_days повторно.
- [x] Новый день создаёт отдельный результат с правильным closing balance; восстановленные данные не обнуляются и не пересчитываются как новые.
- [x] Stale day/phase, замена wallet/cycle, смена World или удаление владельца до flush не меняют чужое состояние.
- [x] После перехода/flush Night snapshot содержит актуальные результаты; повторная запись Night не закрывает смену снова.
- [x] Для обычного и отложенного buffer режима результат совпадает; bootstrap Customers не запускает wallet day reaction.

### Validation

Расширить существующие focused GUT кошелька/календаря сценариями выше; не дублировать уже достаточные тесты. Native parser изменённых scripts/scenes; один non-visual календарь → итог → Night snapshot/restore smoke на завершении этапа.

Применить formatter, structure/domain dependencies и strict architecture gates по validation-workflow. Добавить узкую регрессию против возврата `System.process → Service.sync_day` или эквивалентного polling; текущий regex tick/update/process его не ловит. Не превращать это в запрет всех Service-вызовов из Systems и не добавлять allowlist скрытого scheduler.


### Current
Реализован commerce-owned O_WalletDay на committed DayPhaseChanged и дискретном появлении C_Wallet/C_DayCycle. Callback захватывает WeakRef session, точные Components/day/phase и отвергает заменённый глобальный World. WalletService.sync_day остаётся явной идемпотентной операцией; GameWorld.ready и успешный in-place restore вызывают её после passive reconstruction. Отдельного completion flag и новых SAVE_FIELDS нет.

S_WalletDay и его UID удалены, native game_world.tscn заменяет узел Observer с сохранённым unique_id. Все действующие manifests и Night deps мигрированы; исторические completed records не переписаны. CommandBufferBarrier завершает MANUAL wallet/outcome reactions до Night snapshot. Узкий architecture guard запрещает wallet-day вызов из System, но допускает обычные транзакции.

### Next
Implementation and review are complete. Continue independent PVZ-A01 and resolve the native parser contract in PVZ-B01.

### Dependencies / exclusions
Не изменять тарифы, причины MoneyOperation, settlement rules, покупки и scope прочих доменов. [ConfigFile migration](../pvz_b01_configfile_save_storage.md) независима, но итоговый тест Night выполнить на совместном результате. [PVZ-A03](../pvz_a03_persistence_documentation.md) фиксирует окончательный контракт; [documentation quality](../pvz_code_documentation_quality.md) выполняет завершающую сверку.

### Owner QA / blockers

Gameplay/visual QA **NOT_RUN**, 0/8; rendered playtests не запускались. MCP использован для native scene mutation/save и checked path diagnostics пяти production scripts — ошибок нет. Старый fallback reload code 43 из script writes перепроверен native path diagnostics, а не объявлен PASS сам по себе.

Native save побочно записал восемь пустых BlackboardPlan и одну UID-аннотацию внешних ресурсов. Main доказал точный metadata-only diff, штатно закрыл editor без dirty scenes и отменил только собственные side effects; исходные планы/пользовательские изменения сохранены. Обратимый patch: `.artifacts/wallet_editor_resave_sideeffects.patch`. В checkpoint эти девять ресурсов не входят.

### Completion
Соблюдать [AGENTS.md](../../../AGENTS.md), [task lifecycle](../../skills/task-lifecycle/SKILL.md), non-visual ограничения и последовательных child agents. GitHub Actions/gh не запускать. Проверки выполнять после связных изменений, не каждого edit. Внести полные base/target/review/fix SHA, реальные PASS/FAIL/NOT_RUN и нерешённые замечания сюда. DONE — только после необходимой валидации/review; затем переместить этот же файл в `completed/` и исправить ссылки.

## Checkpoint evidence

- **PASS**: focused native GUT — wallet day 15/15 (67 assertions), wallet transactions 7/7 (46), WorldSnapshot 37/37 (464), StartupRestore 5/5 (38), DistrictLifecycle 19/19 (167): 83 теста, 782 assertions.
- **PASS**: architecture validator unit suite 19/19, в том числе прямой/deferred polling и false-positive fixtures для явных операций.
- **PASS**: GDQuest formatter/lint, agent smells, strict architecture, полный project structure gate и native ParseChanged (`.artifacts/godot_agent/parsechanged-20261015-155738682.stdout.log`).
- **PASS** финальный two-process Night write/retry/fresh restore, включая replacement Morning 3: `tests/artifacts/night_persistence-write-20261016-015724558.log` и `tests/artifacts/night_persistence-restore-20261016-015737737.log`.
- Существующий disk snapshot contract остаётся Morning-only. Decode/materialization кошельков Evening/Night проверен без повторного completed_days; save schema не расширялась ради этой задачи.
- **PASS**: read-only reviewer `/root/review_cal01`, exact BASE_SHA/TARGET_SHA above; all 22 changed files and necessary snapshot contracts inspected. Architecture/style PASS; no material findings. Main triage: no accepted P0/P1/P2 remain. Reviewer checks NOT_RUN; the executed local checks are listed above.
