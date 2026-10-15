# Сохранение — согласованный снимок, версия и повтор ночной записи

Status: **DONE**

 — принято владельцем 2026-10-15.

Родительский этап: [Утренняя машина](district_morning_truck.md). Порядок выполнения: [общая задача](district_service_update.md).

Зависимости: [Машина — возвраты, дешёвая продажа и утилизация](district_truck_returns_resale.md).

## Task state

### Goal

Проверить согласованный снимок новых подсистем и повтор ночной записи. Версионировать
изменение текущего формата без миграции, удаления или перезаписи несовместимого файла.

### Current

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

Согласованный снимок проверен на реальном main_level и в новом процессе. Исправлен
preflight исторической доставки: после заселения `home_id` погибшего жителя освобождается,
но закрытое предложение сохраняет прежний адрес. Validator разрешает эту историю только
для погибшего resident с освобождённым адресом; активное обязательство отклоняется.
Поля и значения формата не изменены: `AutosaveStore.SCHEMA_VERSION = 12` сохранена.
Название файла историческое, требование схемы 3 не возвращать.

Тесты выбора игровых слотов используют минимальный native каталог main_level вместо
фиктивной сцены с подставленным путём. Расширенный Night smoke проверяет семь полных
доменных агрегатов, два ночных перехода, реальную ошибку I/O, три повтора каждой записи,
fresh-process restore и одно заселение без повторных последствий.
Immutable-SHA review собран и triaged без material findings. Следующее: обязательная
ручная приёмка; автоматическая работа района продолжается в итоговой интеграции.

### Validation

Фактические проверки 2026-10-10, Godot 4.7.1, текущий worktree с сохранёнными
пользовательскими изменениями; это не доказательство тестирования immutable snapshot:

- GUT через `utils/godot_agent.ps1 -Action GUT -TestPath res://tests/gut/<file>.gd`:
  `test_world_snapshot` 30/30, 352 asserts (`gut-20261010-134923778`),
  `test_game_session` 6/6, 43 (`gut-20261010-133636661`),
  `test_save_data` 6/6, 40 (`gut-20261010-133050853`) — wrapper PASS.
- `test_district_snapshot` 13/13, 130 (`gut-20261010-134644372`) и
  `test_refactoring_v2_persistence_baseline` 5/5, 336 (`gut-20261010-133053202`): assertions/native exit 0;
  wrapper FAIL из-за shutdown-only Resource/RID retention. Всего 60 tests / 901 asserts.
- Parser текущих пяти скриптов PASS (`parsefiles-20261010-135811294`).
  District fixture отдельно: native parser PASS 1/1, exit 0;
  `.artifacts/godot_agent/task16-district-isolated-parser.log` сохраняет shutdown warnings.
  Пакетный parser шести файлов FAIL (`parsefiles-20261010-134937938`): helper считает
  эти warnings ошибкой isolated compilation. Реальных compile failures нет.
  Shutdown-only категория — `KNOWN_ENGINE_LIMITATION / DEFERRED`, не fake wrapper PASS.
- `utils/run_smoke.ps1 -Name night_persistence -GodotPath .bin/Godot_v4.7.1-stable_win64_console.exe -Frames 1600`:
  write/restore PASS/PASS; `tests/artifacts/night_persistence-write-20261010-234658155.log`
  и `night_persistence-restore-20261010-234716388.log`; без runtime/script errors.
- Raw earlier/fresh-instance restore, pending recipe rejection и cargo capture barrier
  уже проверены в [задаче груза](district_truck_returns_resale.md); здесь smoke дополнительно
  восстанавливает native raw tombstone вместе с двумя cargo receipts.
- PASS: incremental formatter/lint (6 files), staged agent-change gate,
  strict architecture (0 findings), strict domain dependencies, project structure и
  persistence baseline inventory. Общий многодневный smoke — финальная задача.

### Owner QA / blockers

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

Связанные чеклисты: [Ручная приёмка сохранений](../../../.qa/tasks/district_save_snapshot.md)

## Границы и владельцы

- `content/domains/persistence/services/world_snapshot_service.gd`, `save_data_codec.gd`,
  `night_save_service.gd`, `autosave_store.gd` и `snapshot_restore_boundary.gd`.
- `content/domains/persistence/rules/district_snapshot_rules.gd`,
  `content/domains/persistence/systems/s_night_save.gd` и доменные `SAVE_FIELDS` новых записей.
- `content/domains/persistence/services/raw_physics_snapshot.gd`,
  `content/domains/interaction/services/raw_physics_actor_service.gd`,
  `content/domains/packages/contracts/truck_cargo_receipt.gd` и
  `content/scenes/game_session_service.gd` для raw-body/журнала и выбора игровых слотов.

`S_NightSave` владеет scheduled workflow/retry; codec/store/snapshot — явными операциями.
Домены владеют своими сохранёнными полями; не импортировать persistence adapter в gameplay.
Восстановление пассивное до readiness: не повторяет default-state реакции и эффекты.

Применять по области: [save-systems](../../skills/save-systems/SKILL.md), [gut-testing](../../skills/gut-testing/SKILL.md).

## Работы

- [x] Сверить snapshot поступлений, заметок, жалоб/уведомлений, предложений и цены торга, ожидающего дропа, мебели, партии машины и операций продажи.
- [x] Сверить raw/scriptless placements с журналом груза: стабильные
  `raw_actor/placed/<UUID>`, presence/pose и native authored recipe. Более ранний снимок
  возвращает утилизированный предмет, более поздний убирает его из новой сцены;
  grab-proxy/NodePath/instance ID не сохраняются. Неполная утилизация ad-hoc runtime тела
  без рецепта отклоняется до мутации; capture посреди cargo commit также отклоняется.
- [x] Сохранить отсутствующих/погибших постоянных NPC и согласованное размещение; Node, Blackboard и кеши восприятия не сериализовать.
- [x] Проверить повтор ночного перехода/ошибку записи: не повторяются выплаты, последствия обещаний, коробки, жители и заселение.
- [x] При изменении сохранённых полей/путей/смысла повысить фактическую supported schema;
  обновить closed guards, golden fixture и save-visible inventory. Неподдерживаемые
  старые/newer/invalid форматы отвергать до изменения мира с понятным сообщением.
- [x] Сохранить несовместимый файл побайтно и защитить rejected slot от последующего
  Night/autosave; замена только через явный New Game или другой slot, без конвертера.
- [x] Проверить восстановление в новой сессии, а не только encode/decode одного объекта.
  Проверки используют отдельные тестовые слоты и native authored fixtures;
  не перезаписывают сохранения владельца и не ослабляют preflight ради фиктивной сцены.
- [x] Собрать и triage immutable-SHA review.
- [x] Закрыть обязательную owner acceptance.

## Review findings

BASE_SHA: `6afc35eb19378584eb23d2f83f823d58574f25e1`.
TARGET_SHA: `fac3929b6041770ecddf6ea7eadeec7f10fba02a`.
Review state: COLLECTED / TRIAGED; material findings отсутствуют.
Один independent read-only reviewer: ARCHITECTURE/STYLE PASS, VALIDATION NOT_RUN.
Main проверил выводы по source/current contracts; worktree engine results записаны выше.

## Критерии завершения

- Текущий поддерживаемый формат восстанавливает согласованный мир без дубликатов.
- Несовместимое сохранение остаётся на диске; повтор ночной записи не повторяет доменные операции.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.

