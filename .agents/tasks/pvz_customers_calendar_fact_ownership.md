# PVZ-CAL01 — Customers не публикует чужой календарный факт

Status: **IN_PROGRESS**
Priority: **P2**
Updated: 2026-10-16.
BASE_SHA: `954be4d2a7a0087ce08461bc1fbdd8074f815e67`.
Implementation TARGET_SHA: `bc60759e4a7ef420cd8925a834ef7bc6687aee54`.

## Task state

### Goal

Убрать использование DayPhaseChanged как скрытой команды восстановления Customers. Реальный календарный факт публикует владелец календарного перехода; инициализация/сверка планирования имеет отдельный явный путь.

### Current

Реализация закоммичена и прошла независимое immutable review. Приняты RV-001/P1 и RV-002/P2, воспроизведены native GUT и исправлены в текущем repair batch; targeted re-review ещё не выполнено. Этап не DONE.

Только S_DayPhase публикует DayPhaseChanged после изменения календаря. Customers используют CustomerPlanningRequest.RECONCILE_SESSION, District — DistrictCalendarReconcileRequest. Ready и успешный in-place restore явно отправляют запросы и завершают bounded command quiescence. Startup restore откладывает сверку до global ready. S_CustomerFlow сохраняет arrival clocks/history и восстанавливает только отсутствующий контекст, не повторяя pending-запрос. Схема сохранения и баланс не менялись.

### Next

Закоммитить repair batch, закрепить полный fix SHA и передать одному read-only reviewer только RV-001/RV-002 и regression tests. Собрать triage. Отдельно завершить и отревьюить [TASK-META01](task_metadata_structure_gate.md), затем подтвердить общий structure gate и архивировать исходные records без дубликатов.

### Validation

- **PASS** до repair: native ParseChanged; GDQuest formatter/lint, agent smells, strict architecture и strict domain dependencies.
- **PASS**: CustomerPlanning 16/16 (82 assertions), DistrictLifecycle 19/19 (167), CustomerOutcomes 7/7 (63), WorldSnapshot 36/36 (449), StartupRestore 5/5 (32): всего 83 теста, 793 assertions.
- **PASS**: two-process Night write/retry/restore smoke, включая replacement Morning 3: `tests/artifacts/night_persistence-write-20261016-012743611.log` и `tests/artifacts/night_persistence-restore-20261016-012757823.log`.
- **FAIL до repair**, ожидаемое воспроизведение RV-001/RV-002: `.artifacts/godot_agent/gut-20261015-153414478.stdout.log` и `gut-20261015-153420696.stdout.log`.
- **PASS repair**: CustomerPlanning 18/18 и CustomerOutcomes 8/8; native ParseChanged, formatter/lint, agent smells, strict architecture и полный structure gate. Targeted re-review ещё не завершено.
- Full structure до metadata checkpoint: **FAIL**, 81 baseline task-format finding на BASE_SHA, introduced = 0; нормализация собственного record оставила 78. Независимый TASK-META01 теперь даёт **PASS** текущей worktree без ослабления validator; его commit/review ещё впереди.

### Owner QA / blockers

Gameplay/visual QA: **NOT_RUN**, 0/8 проверок; rendered playtests не запускались. Субъективная визуальная приёмка не заявляется.

MCP подключён к Godot 4.7.1; записи и diagnostics проверялись. Для загруженных production scripts live reload возвращает fallback error code 43; CLI native parser проходит, чистота live reload не заявляется. Новые скрипты и изменённые тесты получили checked diagnostics без ошибок. Известные shutdown-only retention warnings Godot 4.7.1 не расширяют scope этой задачи.

### Constraints / completion

Единственный planning owner — O_CustomerPlanning; календарь, визиты, экономика, GECS scheduling и физическая власть не перепроектируются. Components/Relationships остаются единственными владельцами состояния. Requests не completed до реального callback/flush; исчезнувшие владельцы, заменённые Components/World, day/phase/generation отвергаются на queued boundary. Null-owner допустим только для прежних изолированных data fixtures.

Использованы навыки GECS v8, GDScript style, validation, refactoring, GUT, task lifecycle, Godot MCP и review orchestration. Нет нового scheduler/service tick, no-op System, allowlist или legacy пути. Один child reviewer; без сторонних addon edits, GitHub Actions/gh и rendered gameplay.

## Acceptance / focused regressions

- [x] Bootstrap/reconcile Customers и District не публикуют DayPhaseChanged и не будят чужих календарных подписчиков.
- [x] Реальный Morning → Day → Evening → Night публикует факты после committed mutation.
- [x] Fresh startup и safe restore явно готовят клиентов после passive construction один раз на контекст.
- [x] Повторы не дублируют визиты, registration penalties, followups и morning preparation/offers.
- [x] Pending receipt объединяет повторные ticks; отказ допускает восстановление актуального контекста.
- [x] Component/World/day/phase/generation и freed owner покрыты native GUT; review уточнил две дополнительные границы, исправления проверяются отдельно.
- [x] PER_CALLBACK и MANUAL, включая обратный порядок outcomes/planning, завершают подготовку на объявленной границе; нет синхронного ожидания scheduler.
- [x] Arrival cooldown/history и immutable Night retry/preparation сохраняют семантику. Smoke сравнивает все durable-поля с точными изменениями фазового входа.
- [ ] RV-001/RV-002 закрыты fix SHA, final checks и targeted re-review; review не pending.
- [ ] Полный structure gate подтверждён после отдельного metadata checkpoint.

## Review findings

Source: BASE_SHA `954be4d2a7a0087ce08461bc1fbdd8074f815e67` → TARGET_SHA `bc60759e4a7ef420cd8925a834ef7bc6687aee54`. Read-only reviewer не запускал тесты и не использовал mutable worktree/MCP. Style PASS; обе кандидатуры приняты Main.

- **RV-001 / P1 / ACCEPTED (repair implemented, verification pending)** — O_CustomerOutcomes._reconcile_prepared: MANUAL результат старого World мог взять новый глобальный wallet. Воспроизведён лишний MoneyOperation и settlement старого визита. Main добавил проверку ECS.world == _world и regression с двумя Worlds; оба кошелька и старый визит должны оставаться неизменными.
- **RV-002 / P2 / ACCEPTED (repair implemented, verification pending)** — O_DistrictLifecycle._on_reconstruction: поиск через текущие Components терял pending receipt после замены C_District/удаления session. Оба сценария воспроизведены. Main учитывает фактически queued requests и завершает их до очистки callbacks независимо от текущей query; свежая подготовка проверяется отдельно.

Кириллица task record, повреждённая PowerShell→Python pipe в implementation checkpoint, исправлена UTF-8-safe записью; runtime-код писался через MCP и этой ошибке не подвергался.

## Dependencies

Выполнить перед [PVZ-A02: кошелёк](pvz_a02_wallet_day_events.md). ConfigFile migration независима; перед общей приёмкой нужен совместный startup/Night integration. Документация сверяется в [PVZ-A03](pvz_a03_persistence_documentation.md) и [PVZ-DOC01](pvz_code_documentation_quality.md).

DONE — только после обязательных проверок и review/triage; затем перенос этого же файла в completed с обновлением ссылок. [TASK-META01](task_metadata_structure_gate.md) закрывает исходный metadata defect, не меняя gameplay acceptance.
