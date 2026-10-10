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
продажа/raw disposal и следующий утренний возврат, физическая мебель, очередь/свет
второго дня, семь полных сохранённых агрегатов и два повторных reload без выплат/дубликатов.
Fixture задаёт физические входы игрока/разгрузки и home pose; движение очереди обычное.
Три предложения выбираются на копии Definition, перед Night возвращается authored .tres.
Следующее: закрыть финальные parser/import/export gates и immutable-SHA review/triage.
Windows build NOT_RUN; source review нового сценария REVIEW_PENDING.

Baseline district smoke выявил устаревший legacy junction graph gate. Исправление и
review/triage закрыты в [задаче validator](completed/warehouse_navigation_validation_contract.md).
Повторный недельный district smoke PASS: семь дней, Night/save/restore и 12 records/bodies
через Morning8. Этот сценарий не покрывает все требуемые терминал/LOST/доставку/мебель/груз;
связная итоговая приёмка остаётся открытой. Геометрия/navmesh владельца не изменялись.

### Validation

Приёмка ещё открыта. Проверки 2026-10-11 выполнялись на worktree с сохранёнными
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
- Live MCP script writes: diagnostics checked, без file errors/warnings. Предварительный
  CLI parser 1/1, native exit 0 (`parsefiles-20261010-152158813`), wrapper FAIL из-за
  shutdown-only retention. Финальный parser после comparator repair ещё NOT_RUN.

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
- [ ] Собрать Windows QA в .export штатным способом и проверить запуск в разрешённом headless режиме.
- [ ] Записать фактические команды/результаты; не считать раннюю контрольную точку или остановленный по лимиту прогон итоговым PASS.
- [x] Оформить ручные пункты маршрутов, BT, мерцания, UI, ловушки, мебели и машины.
  Обязательная owner acceptance оставляет задачу активной до решения владельца;
  чеклист не отменяет её. DONE/архивирование — после всех required gates и review/triage;
  явно отложенные subjective polish пункты можно передать в `qa_tasks/`.

## Критерии завершения

- Автоматическая интеграция имеет подтверждённый результат и runnable QA-сборку.
- Реализация, автоматическая приёмка и review/triage распределённых задач завершены;
  ручная приёмка явно записана и не объявлена выполненной. До закрытия обязательной
  owner acceptance задача остаётся OWNER_QA, а родительский этап не становится DONE.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.

