# Район — итоговая интеграция и Windows QA

Status: **IN_PROGRESS**

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

Выполнять после завершения реализации, автоматических проверок и review/triage
функциональных задач, snapshot-аудита текущего формата (сейчас schema 12) и задачи
инструментов. Их отдельная OWNER_QA не препятствует headless интеграции и подготовке
сборки; обязательная ручная приёмка остаётся открытой в owning tasks.
Функциональный snapshot checkpoint reviewed; задача инструментов завершена после
проверки scanner repair RV-001 и targeted re-review. Найдены текущие runners
`utils/run_smoke.ps1` и `utils/export_windows.ps1`,
существующие district/Night/truck/furniture smokes и профильные GUT. Новый
`tests/smoke/district_release_smoke.tscn` проходит реальные shifts/Nights 1/2 через
обычные Systems и `DayPhaseService`, затем startup Morning3 в отдельном процессе.
Проверены terminal LOST/заметка/принятие предложений, success/refusal/failed promise,
продажа/raw disposal и следующий утренний возврат, физическая мебель и очередь второго
дня. Семь полных агрегатов сверяются после restore; повторные операции проверяют wallet.
Причина light timeout и нефинансовая идемпотентность ещё требуют усиления acceptance
по RV-001/002 ниже; native smoke PASS сам по себе эти пробелы не закрывает.
Fixture задаёт физические входы игрока/разгрузки и home pose; движение очереди обычное.
Три предложения выбираются на копии Definition, перед Night возвращается authored .tres.
Source checkpoint: `22ec1db34b4c0b5962b0a5f8f92e65169c8633cf`.
Рабочий fix RV-001/002 подготовлен: ожидание наблюдается по visit ID и текущему дню,
сверяется точная authored причина и отсутствие settlement; после повторных операций
сверяются все семь агрегатов и физическая мебель, отдельный счётчик требует обе проверки.
Первый усиленный write FAIL (`tests/artifacts/district_release-write-20261012-023802121.log`):
светобоязненный npc/7 перенёс визит из-за недоступного пути, предупреждения света не было.
Это подтверждает прежний validation gap, а не light timeout. Fixture теперь размещает
реальных светобоязненных жителей на авторских точках очереди перед созданием новой партии;
их дальнейшим движением, предупреждением и timeout владеют обычные BT/Systems.
Следующее: получить успешный полный write/restore на этом fixture, targeted re-review,
затем закрыть итоговый validation/export batch. Windows build NOT_RUN.

Baseline district smoke выявил устаревший legacy junction graph gate. Исправление и
review/triage закрыты в [задаче validator](completed/warehouse_navigation_validation_contract.md).
Повторный недельный district smoke PASS: семь дней, Night/save/restore и 12 records/bodies
через Morning8. Этот сценарий не покрывает все требуемые терминал/LOST/доставку/мебель/груз;
связная итоговая приёмка остаётся открытой. Геометрия/navmesh владельца не изменялись.

### Validation

Приёмка ещё открыта. Актуальные проверки 2026-10-12 на пользовательском dirty worktree:

- GUT `test_world_snapshot`: PASS 30/30, 352 assertions;
  `.artifacts/godot_agent/gut-20261011-163946671.stdout.log`.
  `test_game_session`: PASS 6/6, 43 assertions (`gut-20261011-164042998`); оба wrapper PASS.
- PASS: incremental formatter/lint, agent-change gate, strict architecture/domain structure,
  domain dependencies, project structure и scoped `git diff --check`.
- Dialogue native compiler/current imported data: PASS 3/3, zero failures;
  `offlinescript-20261011-164407279.stdout.log`. Native exit 0; wrapper FAIL только
  по shutdown RID/Resource retention, KNOWN_ENGINE_LIMITATION / DEFERRED.
  Воспроизводится `utils/godot_agent.ps1 -Action OfflineScript
  -ScriptPath res://utils/validate_district_dialogues.gd` при закрытом редакторе.
- Parser `parsefiles-20261011-164759067`: 2/2, native exit 0, runtime/script errors нет;
  wrapper FAIL по shutdown-only retention. До этого параллельный parser native crash
  (`parsefiles-20261011-164356823`) не является PASS; последовательный повтор завершился.
- Live MCP: проектный editor PID 15008, ownership report без unsaved scenes;
  финальный `script_patch` smoke checked/reloaded, diagnostics empty.
  Editor log содержит четыре ошибки намеренных cyclic authoring fixtures, вне этого smoke;
  это не shutdown retention и не доказательство чистоты всего editor log.
- Connected write/restore после финального fixture: RUNNING / результат ещё не принят.
  RV-001/002 и Windows export остаются открыты до фактической verification/re-review.

Предыдущие проверки 2026-10-11 выполнялись на worktree с сохранёнными
пользовательскими изменениями; они не являются тестированием immutable snapshot:

- Connected smoke: native write/restore PASS, exit 0; логи
  `tests/artifacts/district_release-write-20261011-012324176.log` и
  `district_release-restore-20261011-012536592.log`. Runtime/script errors отсутствуют.
  Runner write FAIL из-за shutdown-only Resource/Script/texture RID retention;
  restore выполнен отдельным headless процессом с `-- restore`, поскольку runner
  останавливается после FAIL. Diagnostics сохранены: KNOWN_ENGINE_LIMITATION / DEFERRED;
  wrapper FAIL не объявлять PASS. Обычный запуск:
  `utils/run_smoke.ps1 -Name district_release -GodotPath .bin/Godot_v4.7.1-stable_win64_console.exe`.
- GUT: `test_world_snapshot` 30/30, 352 assertions (`gut-20261010-152354786`) и
  `test_game_session` 6/6, 43 (`gut-20261010-152358489`), wrapper PASS.
- PASS: incremental formatter/lint, staged agent-change gate (0 production files),
  strict architecture/domain, project structure, PowerShell parser и scoped diff check.
- Live MCP script writes: diagnostics checked, без file errors/warnings. Финальный
  CLI parser после comparator repair: 1/1, native exit 0 (`parsefiles-20261010-152746651`),
  wrapper FAIL из-за shutdown-only retention; runtime/script errors отсутствуют.
- Offline Import выполнен при закрытом редакторе: native exit 0
  (`import-20261010-152757603`), wrapper FAIL из-за shutdown-only Resource/RID retention.
  Лог подтверждает filesystem/class/plugin initialization; отдельного подтверждения
  повторного импорта всех `.dialogue` нет. Dialogue acceptance остаётся открытой.
- Source review собран и triaged: два ACCEPTED P2 validation gaps, см. RV-001/002.
  Reviewer: ARCHITECTURE FAIL, STYLE PASS, VALIDATION NOT_RUN.

Итоговый реальный parser через `utils/godot_agent.ps1`, incremental formatter,
`validate_agent_changes.py`, strict architecture/domain, структура, импорт диалогов,
профильный GUT, fresh-process roundtrip/rejected-slot protection, многодневный headless
smoke, Windows export/headless startup и `git diff --check`. Записать immutable-SHA
review/triage по [review-orchestration](../.agents/skills/review-orchestration/SKILL.md).
MCP недоступность не заменяет engine checks; shutdown-only retention классифицировать
по текущей политике KNOWN_ENGINE_LIMITATION / DEFERRED.

### Owner QA / blockers

Rendered gameplay, визуальная съёмка и субъективная приёмка владельца не выполняются автоматически.
Подготовлен [связный чеклист итоговой сборки](../qa_tasks/district_release_validation.md),
PENDING_OWNER_QA; runnable build для этой приёмки ещё NOT_BUILT.

## Границы и владельцы

- Существующие профильные тесты, `tests/smoke/`, штатные validation/export инструменты и `.export/`.
- Четыре родительские задачи, корневая задача и новый чеклист `qa_tasks/`.

Применять по области: [gut-testing](../.agents/skills/gut-testing/SKILL.md), [godot-ai-mcp](../.agents/skills/godot-ai-mcp/SKILL.md).

## Работы

- [ ] Одним связным пакетом выполнить parser изменённых проектных скриптов, импорт диалогов, структуру и профильный GUT; устранить новые релевантные предупреждения.
- [ ] Провести один ограниченный многодневный headless smoke: второй день, очередь/свет, терминал/ручной LOST, доставка, мебель, машина и сохранение без повторных операций.
- [ ] Закрыть RV-001/002 проверками причины light deferral и полных последствий повторных операций; собрать targeted re-review.
- [ ] Собрать Windows QA в .export штатным способом и проверить запуск в разрешённом headless режиме.
- [ ] Записать фактические команды/результаты; не считать раннюю контрольную точку или остановленный по лимиту прогон итоговым PASS.
- [x] Оформить ручные пункты маршрутов, BT, мерцания, UI, ловушки, мебели и машины.
  Обязательная owner acceptance оставляет задачу активной до решения владельца;
  чеклист не отменяет её. DONE/архивирование — после всех required gates и review/triage;
  явно отложенные subjective polish пункты можно передать в `qa_tasks/`.

## Review findings

BASE_SHA: `6120e69b93de80cfa2c30b4dc2798cc41185659f`.
TARGET_SHA: `22ec1db34b4c0b5962b0a5f8f92e65169c8633cf`.
Review state: COLLECTED / TRIAGED; два ACCEPTED P2, fix owner — Main.
Замечания относятся к исходному immutable target; это пробелы acceptance, не доказанные
production-регрессии. Fix SHA / targeted re-review: pending текущего checkpoint;
verification полного write/restore ещё не завершена.

- RV-001 (R1), `_serve_counter`: `deferred_day` + LIGHT_AVERSION не доказывают light
  timeout. `NpcServiceRole.defer_visit` переносит визиты и по другим причинам.
  Наблюдать у одного visit WAITING_FOR_DARKNESS и `light_warning_started`, затем
  light-specific `defer_reason` из authored service BT; сверить отсутствие settlement.
  Перенос из-за опасности/недоступности не должен удовлетворять этой проверке.
- RV-002 (R2), `_restore_acceptance`: полные доменные агрегаты/physical goods проверяются
  до повторных `fulfill_one`, `complete`, `finish_evening`; после них — только wallet.
  Сверять durable aggregates и физические goods также после повторных операций,
  до следующего restore. Изменение памяти обещаний, visits/history или commerce должно
  проваливать acceptance даже при неизменном wallet; не ослаблять completion counters.

Оба пункта относятся к [connected smoke](../tests/smoke/district_release_smoke.gd).
Открытые ACCEPTED P2 блокируют DONE; engine shutdown deferral их не отменяет.

## Критерии завершения

- Автоматическая интеграция имеет подтверждённый результат и runnable QA-сборку.
- Реализация, автоматическая приёмка и review/triage распределённых задач завершены;
  ручная приёмка явно записана и не объявлена выполненной. До закрытия обязательной
  owner acceptance задача остаётся OWNER_QA, а родительский этап не становится DONE.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.

