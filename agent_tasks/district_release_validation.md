# Район — итоговая интеграция и Windows QA

Status: **OWNER_QA**

Родительский этап: [Утренняя машина](district_morning_truck.md). Порядок выполнения: [общая задача](district_service_update.md).

Зависимости: автоматическая приёмка и review/triage [gate](district_truck_shift_gate.md),
[обратного груза](district_truck_returns_resale.md), [snapshot](district_save_schema_3.md),
[инструментов](completed/district_bin_cleanup.md) и
[контракта navigation validator](completed/warehouse_navigation_validation_contract.md).
Их открытая owner QA не блокирует подготовку автоматической приёмки и сборки.

## Task state

### Goal

Завершить связную автоматическую приёмку всех этапов и подготовить runnable Windows QA-сборку с отдельными ручными пунктами.

### Current

Автоматическая приёмка завершена 2026-10-12; обязательная owner QA остаётся открытой.
Code checkpoint: `0f2d65b980c53a22337736e6b5b9b2cbf07bcc42`. Connected
`tests/smoke/district_release_smoke.tscn` проходит реальные shifts/Nights 1/2 через
обычные Systems и `DayPhaseService`, затем startup Morning3 в отдельном процессе.
Проверены terminal LOST/заметка/принятие предложений, success/refusal/failed promise,
продажа/raw disposal и следующий утренний возврат, физическая мебель и очередь второго
дня. Семь полных агрегатов и физическая мебель сверяются после restore и после каждого
повтора fulfill/complete/finish_evening до следующего restore; counters 3/3 + 2 сохранены.
RV-001/002/003 FIXED; independent targeted review без material findings.
Fixture задаёт физические входы игрока/разгрузки и home pose; движение очереди обычное.
Три предложения выбираются на копии Definition, перед Night возвращается authored .tres.
Source checkpoint: `22ec1db34b4c0b5962b0a5f8f92e65169c8633cf`.
Fix RV-001/002 проверен: ожидание наблюдается по visit ID и текущему дню,
сверяется точная authored причина и отсутствие settlement; после повторных операций
сверяются все семь агрегатов и физическая мебель, отдельный счётчик требует обе проверки.
Первый усиленный write FAIL (`tests/artifacts/district_release-write-20261012-023802121.log`):
светобоязненный npc/7 перенёс визит из-за недоступного пути, предупреждения света не было.
Это подтверждает прежний validation gap, а не light timeout. Попытка размещения до новой
партии также FAIL: lifecycle активации заменяет раннюю позицию (RV-003 ниже).
Fixture теперь размещает получателя один раз после фактического создания native QUEUED
визита; дальнейшим движением, предупреждением и timeout владеют обычные BT/Systems.
В следующем прогоне warning наблюдался, но aura/опасная зона прервала ожидание
(`district_release-write-20261012-025232640.log`); predicate правильно вернул FAIL.
В test-only копии Definition задан поддерживаемый 5-секундный service wait timeout,
чтобы проверить световую ветку до вмешательства опасных NPC; authored 60 секунд не меняются,
перед Night2 восстанавливается исходная Definition. Проверка штатного 60-секундного
ожидания в кадре остаётся обязательной owner QA.
Следующее: обязательная ручная приёмка владельца по связному чеклисту.
Windows QA export/headless PASS,
build `.export/windows/20261011-165403Z-4cec6443-district-release/`, dirty worktree recorded.

Baseline district smoke выявил устаревший legacy junction graph gate. Исправление и
review/triage закрыты в [задаче validator](completed/warehouse_navigation_validation_contract.md).
Повторный недельный district smoke PASS: семь дней, Night/save/restore и 12 records/bodies
через Morning8. Этот сценарий не покрывает все требуемые терминал/LOST/доставку/мебель/груз;
его acceptance дополнен текущим connected smoke. Геометрия/navmesh владельца не изменялись.

### Validation

Автоматический batch принят. Проверки 2026-10-12 на пользовательском dirty worktree;
это не immutable runtime validation:

- GUT `test_world_snapshot`: PASS 30/30, 352 assertions;
  `.artifacts/godot_agent/gut-20261011-163946671.stdout.log`.
  `test_game_session`: PASS 6/6, 43 assertions (`gut-20261011-164042998`);
  `test_district_service_queue`: PASS 51/51, 340 (`gut-20261011-170049069`). Wrappers PASS.
- PASS: incremental formatter/lint, agent-change gate, strict architecture/domain structure,
  domain dependencies, project structure и scoped `git diff --check`.
- Dialogue native compiler/current imported data: PASS 3/3, zero failures;
  `offlinescript-20261011-164407279.stdout.log`. Native exit 0; wrapper FAIL только
  по shutdown RID/Resource retention, KNOWN_ENGINE_LIMITATION / DEFERRED.
  Воспроизводится `utils/godot_agent.ps1 -Action OfflineScript
  -ScriptPath res://utils/validate_district_dialogues.gd` при закрытом редакторе.
- Final parser `parsefiles-20261011-170129159`: 2/2, native exit 0, runtime/script errors нет;
  wrapper FAIL по shutdown-only retention. До этого параллельный parser native crash
  (`parsefiles-20261011-164356823`) не является PASS; последовательный повтор завершился.
- Live MCP: проектный editor PID 15008, ownership report без unsaved scenes;
  финальный `script_patch` smoke checked/reloaded, diagnostics empty.
  Editor log содержит четыре ошибки намеренных cyclic authoring fixtures, вне этого smoke;
  это не shutdown retention и не доказательство чистоты всего editor log.
- Windows export/headless menu+main level startup: PASS через `utils/export_windows.ps1
  -Label district-release`; manifest `.export/windows/20261011-165403Z-4cec6443-district-release/build_info.json`.
  Источник checkpoint 4cec6443 + сохранённые dirty worktree изменения; это не immutable build.
- Connected native write/restore PASS, exit 0/0, final reviewed code checkpoint:
  `tests/artifacts/district_release-write-20261012-025825843.log` и
  `tests/artifacts/district_release-restore-20261012-030018398.log`.
  Write wrapper FAIL по shutdown-only retention; restore выполнен отдельно через
  `Godot --headless --fixed-fps 60 --path <project> res://tests/smoke/district_release_smoke.tscn
  --quit-after 48000 -- restore`, поскольку wrapper останавливается после write FAIL.
  Три restore/result и два post-operation gates выполнены. Runtime/script errors нет;
  KNOWN_ENGINE_LIMITATION / DEFERRED; wrapper FAIL не объявлять wrapper PASS.

Предыдущий offline Import (`import-20261010-152757603`) не доказывал актуальность
каждого диалога; текущий compiler/import comparator проверил все три imported ресурса.

Выполнены итоговый реальный parser через `utils/godot_agent.ps1`, incremental formatter,
`validate_agent_changes.py`, strict architecture/domain, структура, импорт диалогов,
профильный GUT, fresh-process roundtrip/rejected-slot protection, многодневный headless
smoke, Windows export/headless startup и `git diff --check`. Immutable-SHA
review/triage собран по [review-orchestration](../.agents/skills/review-orchestration/SKILL.md).
MCP недоступность не заменяет engine checks; shutdown-only retention классифицировать
по текущей политике KNOWN_ENGINE_LIMITATION / DEFERRED.

### Owner QA / blockers

Rendered gameplay, визуальная съёмка и субъективная приёмка владельца не выполняются автоматически.
Подготовлен [связный чеклист итоговой сборки](../qa_tasks/district_release_validation.md),
PENDING_OWNER_QA; runnable build подготовлен, см. точный manifest выше.

## Границы и владельцы

- Существующие профильные тесты, `tests/smoke/`, штатные validation/export инструменты и `.export/`.
- Четыре родительские задачи, корневая задача и новый чеклист `qa_tasks/`.

Применять по области: [gut-testing](../.agents/skills/gut-testing/SKILL.md), [godot-ai-mcp](../.agents/skills/godot-ai-mcp/SKILL.md).

## Работы

- [x] Parser, актуальность импортированных диалогов, структура и профильный GUT.
- [x] Многодневный headless smoke: второй день, очередь/свет, terminal/LOST, доставка,
  мебель, машина и сохранение/восстановление без повторных операций.
- [x] RV-001/002/003 проверены; targeted re-review собран и triaged.
- [x] Windows QA в .export и headless startup меню/основного уровня.
- [x] Фактические команды/результаты записаны; native/wrapper статусы разделены.
- [x] Оформить ручные пункты маршрутов, BT, мерцания, UI, ловушки, мебели и машины.
  Обязательная owner acceptance оставляет задачу активной до решения владельца;
  чеклист не отменяет её. DONE/архивирование — после всех required gates и review/triage;
  явно отложенные subjective polish пункты можно передать в `qa_tasks/`.
- [ ] Обязательная owner acceptance, включая authored 60-секундное ожидание света.

## Review findings

BASE_SHA: `6120e69b93de80cfa2c30b4dc2798cc41185659f`.
TARGET_SHA: `22ec1db34b4c0b5962b0a5f8f92e65169c8633cf`.
Review state: COLLECTED / TRIAGED / FIXED; fix owner — Main.
Замечания относятся к исходному immutable target; это пробелы acceptance, не доказанные
production-регрессии. Verification final native write/restore PASS/PASS.
Fix checkpoint: `4cec64434b4937a2f032806d56c3952792687efd`; независимый read-only
review собран, STYLE PASS, ARCHITECTURE FAIL по RV-003, VALIDATION NOT_RUN.
Targeted cycle 1 `4cec64434b4937a2f032806d56c3952792687efd` →
`0f2d65b980c53a22337736e6b5b9b2cbf07bcc42`: no material findings,
ARCHITECTURE/STYLE PASS; reviewer VALIDATION NOT_RUN. Main выполнил проверки выше.

- RV-001 (R1), P2 FIXED `4cec64434b4937a2f032806d56c3952792687efd` + fixture fix ниже.
  `_serve_counter`: `deferred_day` + LIGHT_AVERSION не доказывали light
  timeout. `NpcServiceRole.defer_visit` переносит визиты и по другим причинам.
  Наблюдать у одного visit WAITING_FOR_DARKNESS и `light_warning_started`, затем
  light-specific `defer_reason` из authored service BT; сверить отсутствие settlement.
  Перенос из-за опасности/недоступности не должен удовлетворять этой проверке.
- RV-002 (R2), P2 FIXED `4cec64434b4937a2f032806d56c3952792687efd`.
  `_restore_acceptance`: полные доменные агрегаты/physical goods проверялись
  до повторных `fulfill_one`, `complete`, `finish_evening`; после них — только wallet.
  Сверять durable aggregates и физические goods также после повторных операций,
  до следующего restore. Изменение памяти обещаний, visits/history или commerce должно
  проваливать acceptance даже при неизменном wallet; не ослаблять completion counters.
- RV-003 (новый reviewer R1), P2 FIXED `0f2d65b980c53a22337736e6b5b9b2cbf07bcc42`:
  `_stage_light_recipients` до `_unload(2)` меняет только pose, но native `NpcServiceRole.begin`
  может повторно размещать не-STREET личность. Подтверждение: write
  `district_release-write-20261012-024848572.log` FAIL, npc/7 ROUTE_BLOCKED без warning.
  Fix owner Main: staging один раз после создания native QUEUED роли; native write/restore
  и targeted re-review PASS. Source review intervals 97/47 seconds; serial/token comparison
  NOT_MEASURED, это не завершает parallel pilot.

Пункты относятся к [connected smoke](../tests/smoke/district_release_smoke.gd).
Открытые ACCEPTED P2 блокируют DONE; engine shutdown deferral их не отменяет.

## Критерии завершения

- Автоматическая интеграция имеет подтверждённый результат и runnable QA-сборку.
- Реализация, автоматическая приёмка и review/triage распределённых задач завершены;
  ручная приёмка явно записана и не объявлена выполненной. До закрытия обязательной
  owner acceptance задача остаётся OWNER_QA, а родительский этап не становится DONE.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.

