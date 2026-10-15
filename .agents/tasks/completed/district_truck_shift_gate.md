# Машина — разгрузка и условия начала смены

Status: **DONE**

 — принято владельцем 2026-10-15.

Родительский этап: [Утренняя машина](district_morning_truck.md). Порядок выполнения: [общая задача](district_service_update.md).

Зависимости: [Машина — утреннее появление и входящие коробки](district_truck_morning_spawn.md).

## Task state

### Goal

Разрешать начало смены только после завершённой поставки, разгрузки/ручной потери и выхода игрока из кузова.

### Current

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

Gate уже реализован: `ReceivingShiftService.status/commit_departure`, повторная проверка
в `S_DayPhase`, сообщения UI и конечный lifecycle `E_MorningTruck`. Существуют
`tests/gut/test_truck_shift_gate.gd` и `tests/smoke/truck_shift_gate_smoke.tscn`.
Автоматическая приёмка 2026-10-10 выполнена на текущем worktree; gameplay-код gate
не изменён. Source SHA: `878ab6e6226ca4990fd21b0b07f3352098435ade`.
Автоматическая приёмка и independent immutable-SHA review/triage закрыты;
Обратный груз реализован в [своей задаче](district_truck_returns_resale.md);
обязательная ручная приёмка gate остаётся открытой.

### Validation

PASS 2026-10-10, Godot 4.7.1, текущий worktree с сохранёнными пользовательскими изменениями:

- `utils/godot_agent.ps1 -Action GUT -TestPath res://tests/gut/test_truck_shift_gate.gd`:
  26/26, 177 assertions; `.artifacts/godot_agent/gut-20261010-114149679.*.log`.
- `utils/godot_agent.ps1 -Action GUT -TestPath res://tests/gut/test_package_receipts_loss.gd`:
  13/13, 129 assertions; `.artifacts/godot_agent/gut-20261010-114337235.*.log`.
- `utils/godot_agent.ps1 -Action ParseFiles -Paths <список ниже>`:
  6/6, 0 failures; `.artifacts/godot_agent/parsefiles-20261010-114312279.*.log`.
- `utils/run_smoke.ps1 -Name truck_shift_gate -GodotPath .bin/Godot_v4.7.1-stable_win64_console.exe -Frames 360`:
  PASS; `tests/artifacts/truck_shift_gate-20261010-214233133.log`.

Parser Paths: `res://content/domains/packages/services/receiving_shift_service.gd`,
`res://content/domains/packages/entities/e_morning_truck.gd`,
`res://content/domains/time/services/day_phase_service.gd`,
`res://content/domains/time/systems/s_day_phase.gd`,
`res://tests/gut/test_truck_shift_gate.gd`, `res://tests/smoke/truck_shift_gate_smoke.gd`.

Проверены недопоставка, полный физический вынос/возврат с поворотом кузова, missing/destroyed
до ручного LOST, UI-причины/терминальная доступность, игрок до и во время закрытия,
revalidation CommandBuffer, однократный cargo hook до DAY, сохранение ID и bounded departure.
Rendered/owner QA NOT_RUN. Эти проверки принимают gate; финансовая обработка и её
review/triage принадлежат [задаче обратного груза](district_truck_returns_resale.md).

### Owner QA / blockers

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

Связанные чеклисты: [Ручная приёмка сообщений, разгрузки и двери](../../../.qa/tasks/district_truck_shift_gate.md)

## Границы и владельцы

- `content/domains/packages/services/receiving_shift_service.gd`,
  `content/domains/packages/entities/e_morning_truck.gd` и грузовая область.
- `content/domains/time/services/day_phase_service.gd`, `day_phase_queries.gd`,
  `content/domains/time/systems/s_day_phase.gd` и прямое UI причины запрета.
- Контракт ручного LOST, записи входящей партии и обработчик закрытия/диспавна машины.

`C_Receiving`/`ReceivingBatch` владеют данными партии; `S_Receiving` — поставкой по времени,
`S_DayPhase` — исполнением перехода. Проверка/commit сервиса — одна синхронная операция,
а локальное закрытие двери — существующий native lifecycle машины. Сохранить повторную
проверку календаря/Component/lifetime на CommandBuffer boundary до выхода из MORNING.

Применять по области: [godot-physics-4.7](../../skills/godot-physics-4.7/SKILL.md), [game-ui-ux](../../skills/game-ui-ux/SKILL.md).

## Работы

- [x] Общий источник причин запрета для UI и перехода уже есть в `ReceivingShiftService.status`.
- [x] Проверка полного физического выхода и missing/destroyed до ручного LOST существует.
- [x] Причины/количества поставки, оставшихся коробок и игрока внутри возвращаются общей проверкой.
- [x] Native lifecycle двери проверяет игрока и имеет конечное время завершения.
- [x] `cargo_commit_requested` вызывается однократно по партии до выхода из MORNING;
  приёмка финансовых операций принадлежит задаче обратного груза.
- [x] Актуальные parser, GUT и smoke подтверждают автоматическую поверхность UI/терминала/gate.
- [x] Independent immutable-SHA review собран/triaged: material findings отсутствуют.
- [x] Ручная приёмка владельца; только затем DONE/архивирование.

## Review findings

BASE_SHA: `878ab6e6226ca4990fd21b0b07f3352098435ade`.
TARGET_SHA: `2886154d6fffafaea0e455d63a17aa93496b3e58`.
Review state: TRIAGED; no material findings. ARCHITECTURE/STYLE PASS по scoped source
review; reviewer VALIDATION NOT_RUN. Main worktree engine evidence записано выше;
оно не объявляется запуском тестов на immutable snapshot.

## Критерии завершения

- Уничтоженную до регистрации коробку можно вручную отметить LOST и снять требование разгрузки.
- UI и исполнение смены согласованы; дверь не запирает игрока, отъезд не удерживает смену бесконечно.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.

