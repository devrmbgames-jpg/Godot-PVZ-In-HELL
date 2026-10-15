# PVZ-CAL01 — Customers не публикует чужой календарный факт

Status: **DONE**
Priority: **P2**
Updated: 2026-10-16.
BASE_SHA: `954be4d2a7a0087ce08461bc1fbdd8074f815e67`.
Implementation TARGET_SHA: `bc60759e4a7ef420cd8925a834ef7bc6687aee54`.

## Task state

### Goal

Убрать использование DayPhaseChanged как скрытой команды восстановления Customers. Реальный календарный факт публикует владелец календарного перехода; инициализация/сверка планирования имеет отдельный явный путь.

### Current

Реализация и приёмка PVZ-CAL01 завершены. Implementation checkpoint `bc60759e4a7ef420cd8925a834ef7bc6687aee54` прошёл независимое read-only review; RV-001/P1 и RV-002/P2 воспроизведены, исправлены в `9cc33be68ef8fb42ce4ab1965335c6e840722a49` и закрыты targeted re-review без новых findings. Независимый metadata checkpoint `17ea4674872aa7df893405803232c31ab54c4859` также отревьюен, full structure gate PASS. REVIEW_PENDING/BLOCKED и принятых незакрытых P0/P1/P2 нет.

Только S_DayPhase публикует DayPhaseChanged после изменения календаря. Customers и District используют явные coalesced requests с terminal receipts. Ready/in-place restore завершают bounded command quiescence; startup restore откладывает сверку до global ready. Arrival clocks/history, схема сохранения и баланс сохранены.

### Next

PVZ-CAL01 больше не блокирует [PVZ-A02](pvz_a02_wallet_day_events.md). Следующий implementation checkpoint — перенос итогов кошелька с polling на дискретного commerce Observer; остальные задачи не объявлены выполненными.

### Validation

- **PASS**: native ParseChanged, включая final repair; GDQuest formatter/lint, agent smells, strict architecture/domain dependencies и полный project structure gate.
- **PASS** final focused surfaces: CustomerPlanning 18/18 (90 assertions), DistrictLifecycle 19/19 (167), CustomerOutcomes 8/8 (72), WorldSnapshot 36/36 (449), StartupRestore 5/5 (32): 86 тестов, 810 assertions. После repair повторно выполнены обе изменённые suites — 26/26.
- **PASS**: two-process Night write/retry/restore smoke, включая replacement Morning 3: `tests/artifacts/night_persistence-write-20261016-012743611.log` и `tests/artifacts/night_persistence-restore-20261016-012757823.log`.
- **PASS**: independent implementation review/triage и targeted repair re-review. Reviewer проверял immutable snapshots, тесты не запускал.
- **FAIL до repair**, ожидаемое воспроизведение RV-001/RV-002: `.artifacts/godot_agent/gut-20261015-153414478.stdout.log` и `gut-20261015-153420696.stdout.log`; после fix обе регрессии PASS.
- Исходный full structure FAIL — 81 baseline task-format finding, introduced = 0 — устранён отдельным [TASK-META01](task_metadata_structure_gate.md), без ослабления validator.

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
- [x] Component/World/day/phase/generation и freed owner покрыты native GUT; review уточнил две дополнительные границы, исправления прошли targeted GUT и re-review.
- [x] PER_CALLBACK и MANUAL, включая обратный порядок outcomes/planning, завершают подготовку на объявленной границе; нет синхронного ожидания scheduler.
- [x] Arrival cooldown/history и immutable Night retry/preparation сохраняют семантику. Smoke сравнивает все durable-поля с точными изменениями фазового входа.
- [x] RV-001/RV-002 закрыты fix SHA, final checks и targeted re-review; review не pending.
- [x] Полный structure gate подтверждён после отдельного metadata checkpoint.

## Review findings

Source: BASE_SHA `954be4d2a7a0087ce08461bc1fbdd8074f815e67` → TARGET_SHA `bc60759e4a7ef420cd8925a834ef7bc6687aee54`. Read-only reviewer не запускал тесты и не использовал mutable worktree/MCP. Style PASS; обе кандидатуры приняты Main и закрыты. Targeted re-review `9cc33be68ef8fb42ce4ab1965335c6e840722a49` относительно `bc60759e4a7ef420cd8925a834ef7bc6687aee54`: **PASS**, новых findings нет.

- **RV-001 / P1 / FIXED (`9cc33be68ef8fb42ce4ab1965335c6e840722a49`, CustomerOutcomes 8/8)** — O_CustomerOutcomes._reconcile_prepared: MANUAL результат старого World мог взять новый глобальный wallet. Воспроизведён лишний MoneyOperation и settlement старого визита. Main добавил проверку ECS.world == _world и regression с двумя Worlds; оба кошелька и старый визит должны оставаться неизменными.
- **RV-002 / P2 / FIXED (`9cc33be68ef8fb42ce4ab1965335c6e840722a49`, CustomerPlanning 18/18)** — O_DistrictLifecycle._on_reconstruction: поиск через текущие Components терял pending receipt после замены C_District/удаления session. Оба сценария воспроизведены. Main учитывает фактически queued requests и завершает их до очистки callbacks независимо от текущей query; свежая подготовка проверяется отдельно.

Кириллица task record, повреждённая PowerShell→Python pipe в implementation checkpoint, исправлена UTF-8-safe записью; runtime-код писался через MCP и этой ошибке не подвергался.

## Dependencies

Выполнить перед [PVZ-A02: кошелёк](pvz_a02_wallet_day_events.md). ConfigFile migration независима; перед общей приёмкой нужен совместный startup/Night integration. Документация сверяется в [PVZ-A03](pvz_a03_persistence_documentation.md) и [PVZ-DOC01](../pvz_code_documentation_quality.md).

Обязательные проверки и review/triage закрыты; этот исходный record архивирован с обновлением ссылок. [TASK-META01](task_metadata_structure_gate.md) закрывает исходный metadata defect, не меняя gameplay acceptance.
