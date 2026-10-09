# Мебель — выдача заказа следующим утром

Status: **DONE**

Родительский этап: [Лут и торговля](district_loot_commerce.md). Порядок выполнения: [общая задача](../district_service_update.md).

Зависимости: [Торговец — дневная торговля и выбор доставки мебели](district_trader_purchase.md).

## Task state

### Goal

Создать оплаченную мебель следующим утром на явно заданной площадке около ПВЗ без потери заказа при занятости.

### Current

`MainLevel.furniture_delivery_anchor` ссылается на `Entityes/OrderReceiving/FurnitureDelivery`. Маркер добавлен в существующую авторскую зону утренних заказов; её положение, геометрия и навигация не менялись. Перемещение/поворот маркера меняет площадку без правки алгоритма. Перед точечным патчем MCP `get_roots` подтвердил, что main_level не открыт в редакторе.

`def_furniture_delivery_placement.tres` задаёт девять близких позиций в локальных осях маркера. Общий ItemPlacementSolver проверяет пять точек опоры, все действующие формы тела и резервы текущего кадра; общий предел — 16 кандидатов. Траектория от физического источника для доставки не требуется, поэтому её политика отключает только этот луч. Прежний дроп сохраняет проверку пути и мировые оси. Поддержка физических форм проверяется тем же solver до оплаты; неподдерживаемая форма не оставляет оплаченный невыполнимый заказ.

S_OrderDelivery выполняет не более одной попытки за `C_OrderReceiving.retry_seconds` (стартово 1 секунда), только утром. Занятое место оставляет PendingDelivery невыполненным, новое утро/restore снимают временную паузу. Исчерпанная очередь не запускает физические проверки до следующего утра. Слабый индекс прежних физических заказов строится один раз, а не при каждой попытке. Восстановление очищает кеши/резервы/таймеры.

Предмет получает стабильные Entity.id и C_PersistentIdentity, затем заказ отмечается выполненным. Мебель остаётся переносимой и не закрепляется автоматически. Повторные утро/restore и удаление уже выданной мебели не создают копий или повторной оплаты. Совместимость выдачи в сценах, где сама зона является маркером и находится под обычным Node, сохранена. Проверены все функциональные требования родительского этапа; его реализация и автоматическая приёмка завершены, ручная приёмка остаётся владельцу.

### Validation

Фактически выполнено 2026-10-06:

- **83/83 GUT, 968 assertions, 7 scripts**, exit 0. Приёмка всего этапа: `test_furniture_arrival` включает `test_trader_purchase` и `test_trader_furniture`; дополнительно проверены безопасный дроп, содержимое коробок, осмотр, снимок мира, кодек и торговые расчёты.
- Проверены авторский поворот/смещение маркера, полная опора, отсутствие ссылки, занятость, резервы нескольких выдач до/после physics frame, интервалы реального S_OrderDelivery, запрет дневной выдачи, новое утро, блокированный полный снимок, повторный restore выданной мебели и отсутствие воскрешения удалённого товара.
- Неподдерживаемая ConcavePolygonShape3D с непустыми габаритами отклоняется до оплаты: кошелёк, чек и заказ остаются неизменными. Тест отдельно подтверждает, что прежний валидатор габаритов такую заготовку принимал.
- Godot parser: **9 checked, 0 failed**, exit 0; все изменённые .gd, включая тесты/smoke. Новых ошибок/предупреждений скриптов в свежем процессе нет.
- Два процесса headless smoke полного main_level: **write PASS / restore PASS**, exit 0. Настоящий игрок оплачивает полку; вся реальная площадка блокируется, оплаченный остаток сохраняется на диск. Новый процесс восстанавливает заказ и создаёт полку на реальной свободной площадке. Сохранение физического результата и повторный restore дают один предмет и одну оплату.
- Windows QA: **PASS**, preset `Windows QA`; меню и main_level прошли headless startup по **120 кадров**. Финальная сборка: [.export/windows/20261005-175040Z-91dcbde2-district-loot-commerce-final/PVZInHell.exe](../../.export/windows/20261005-175040Z-91dcbde2-district-loot-commerce-final/PVZInHell.exe); запуск — [.export/LATEST.cmd](../../.export/LATEST.cmd). `build_info.json` честно отмечает `working_tree_dirty=true`: сборка сделана из рабочего дерева перед коммитом, с сохранёнными пользовательскими изменениями GECS.
- Структура: FAIL только на **30 прежних ошибках шести неизменённых agent_tasks/r26_***; собственных ошибок нет. `git diff --check` PASS; локальные ссылки проверяются при завершении записи.
- Live MCP использован для записи/диагностики. main_level.gd и новые тестовые скрипты диагностируются чисто; шесть глобальных классов возвращают прежний fallback `gdscript_reload_failed` code 43 без конкретного сообщения. Чистую live-проверку этих классов не заявляем; свежий parser и реальные GUT/smoke их успешно загружают. Редактор владельца не перезапускался.
- Во всех Windows-процессах сохраняется прежняя ошибка чтения root certificate store. Экспорт завершается с exit 0, но его редакторный stderr содержит sandbox-ошибку записи глобальных editor_settings, 6 ObjectDB exit leaks и 3 оставшихся ресурса. Экспорт не называем чистым импортом; оба экспортированных startup-теста PASS. Отрисовка и субъективная приёмка не запускались.

Команды (движок `.bin/Godot_v4.7.1-stable_win64_console.exe`):

```powershell
--headless --path . -s addons/gut/gut_cmdln.gd '-gtest=res://tests/gut/test_furniture_arrival.gd,res://tests/gut/test_safe_loot_placement.gd,res://tests/gut/test_package_contents.gd,res://tests/gut/test_customer_inspection.gd,res://tests/gut/test_world_snapshot.gd,res://tests/gut/test_save_data.gd,res://tests/gut/test_commerce.gd' -gexit
--headless --path . -s utils/validate_district_scripts.gd -- res://content/services/commerce/order_delivery_service.gd res://content/components/commerce/c_order_receiving.gd res://content/systems/gameplay/s_order_delivery.gd res://content/services/gameplay/item_placement_solver.gd res://content/definitions/gameplay/def_item_placement.gd res://content/scenes/main_level.gd res://content/services/persistence/world_snapshot_service.gd res://tests/gut/test_furniture_arrival.gd res://tests/smoke/furniture_arrival_smoke.gd
--headless --path . res://tests/smoke/furniture_arrival_smoke.tscn
--headless --path . res://tests/smoke/furniture_arrival_smoke.tscn -- restore
powershell.exe -NoProfile -ExecutionPolicy Bypass -File utils/export_windows.ps1 -Label district-loot-commerce-final
python utils/validate_project_structure.py
```

Логи: `%TEMP%/furniture_arrival_gut_final.log`, `furniture_arrival_parser_final.log`, `furniture_arrival_smoke_write_final.log`, `furniture_arrival_smoke_restore_final.log`, `furniture_arrival_structure.log`; export/startup логи лежат в папке сборки. Smoke использует только собственный `user://furniture_arrival_smoke.pvzh`, удаляемый после восстановления. Первый GUT прогон обнаружил несовместимость родителя у прежней зоны выдачи; исправлена в сервисе, прежний тест сохранён.

### Owner QA / blockers

Удобство площадки, переноска и связанная приёмка лута/покупки: [ручной чеклист](../../qa_tasks/district_furniture_arrival.md), PENDING_OWNER_QA. Блокеров реализации этой небольшой задачи нет; ограничения текущего редактора/экспорта описаны выше.

## Границы и владельцы

- `content/services/commerce/order_delivery_service.gd`, `PendingDelivery` и прямой обработчик следующего утра.
- Экспортируемая ссылка на маркер площадки в сцене уровня; общий solver безопасного размещения.

Применять по области: [godot-physics-4.7](../../.agents/skills/godot-physics-4.7/SKILL.md), [save-systems](../../.agents/skills/save-systems/SKILL.md).

## Работы

- [x] Задать площадку узлом/Marker3D сцены через экспортируемую ссылку; не зашивать координаты и не менять навигацию.
- [x] На следующем утре создать настоящий переносимый предмет через безопасное размещение.
- [x] При занятой площадке сохранить заказ и ограниченно повторить попытку; не отмечать невыданную мебель выполненной.
- [x] Не превращать доставку в автоматическую установку мебели; повторное утро/восстановление не создаёт копию.
- [x] Завершить приёмку лута и торговли, обновить родительский этап и записать связный коммит.

## Критерии завершения

- Один оплаченный заказ создаёт один предмет на авторской площадке.
- Занятость и перезапуск не теряют заказ; требования третьего этапа имеют фактическую приёмку.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.
