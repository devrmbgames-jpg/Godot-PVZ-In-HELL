# Машина — утреннее появление и входящие коробки

Status: **DONE**

Родительский этап: [Утренняя машина](../district_morning_truck.md). Порядок выполнения: [общая задача](../district_service_update.md).

Зависимости: [Мебель — выдача заказа следующим утром](district_furniture_arrival.md).

## Task state

### Goal

Заменить утреннее появление коробок одной машиной на авторской стоянке и одной устойчивой входящей партией.

### Current

Подключена существующая машина с `E_MorningTruck`, экспортируемыми `cargo_slots`, `cargo_area`, `door_animation` и общей политикой физического размещения. `ReceivingZone.truck_parking` основной сцены указывает на `TruckParking`; его исходная поза следует `DebugMarkers/CarZone`. Утром создаётся один статичный экземпляр и открывается существующая дверь. Коробки появляются по 12 авторским нижним/верхним маркерам, после проверки всех форм и пяти точек опоры. Занятость сохраняет остаток и возобновляет поставку при разгрузке. Позы тел задаются до входа в SceneTree; стены, геометрия автомобиля и пользовательская навигация сохранены.

`C_Receiving` сохраняет ID партии и состав ожидаемых package_id; `ReceivingBatch` фиксирует физические варианты один раз. Физическое поступление публикует существующую историю без регистрации/номера. Полный снимок сохраняет остаток, а временные резервы/паузы восстанавливаются заново. PackedStringArray копируются при encode/decode: изменение живой или восстановленной партии не меняет ранее записанный снимок. Достигнутый лимит ожидания приостанавливает остаток вместо удаления партии.

Технический диспавн при уходе из утра подключён; единый запрет начала смены, проверка разгрузки/игрока и финальное закрытие двери принадлежат следующей задаче. Обратный груз, схема 3 и итоговая сборка здесь не реализовывались.

### Validation

Фактически выполнено 2026-10-06:

- **97/97 GUT, 873 assertions**, семь скриптов; exit 0. Новая поверхность машины — 10 тестов: стоянка/поворот/дверь, один экземпляр, изменение маркера, занятый кузов, полная форма у стены, реальная укладка, история/ID, предел ожидания, независимые снимки, временный контекст и отклонение неразрешённой сохранённой сцены. Дополнительно пройдены receiving limits, save data, safe loot, world snapshot, receipts/loss и furniture arrival.
- **Godot parser 13/13**, exit 0: все 11 изменённых игровых скриптов и два новых проверочных скрипта.
- **Двухпроцессный headless smoke настоящего main_level write/restore PASS/PASS**, exit 0. Первый процесс фиксирует один реальный груз и занятое место; второй восстанавливает коробку/остаток, моделирует вынос и завершает ту же поставку. Проверены пять реальных коробок, пять поступлений без номера, длительное утро, повтор restore и технический диспавн без удаления выгруженных коробок. Используется собственный слот `user://morning_truck_smoke.pvzh`; слот удалён после restore.
- `git diff --check`: PASS; 67 локальных ссылок проверены, отсутствующих нет. `python utils/validate_project_structure.py`: FAIL **только на прежних 30 ошибках** блоков Task state шести неизменённых `agent_tasks/r26_*`. Новые сцены/скрипты/ресурсы/задачи ошибок структуры не добавляют.
- Headless Editor import: exit 0; без ошибок игровых скриптов. Остаются прежние сообщения sandbox о сохранении глобальных editor_settings, 6 ObjectDB/3 resources при выходе import и недоступном системном хранилище сертификатов.
- MCP: новые скрипты машины/тестов checked без diagnostics. Переопределяемые глобальные классы дают прежний fallback `gdscript_reload_failed 43`; свежий parser/runtime проверяет их успешно, новых записей editor logger после cursor 3 нет. Live reload глобальных классов не объявляется чистым.

Команды:

```powershell
& .bin/Godot_v4.7.1-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd '-gtest=res://tests/gut/test_morning_truck.gd,res://tests/gut/test_receiving_limits.gd,res://tests/gut/test_save_data.gd,res://tests/gut/test_safe_loot_placement.gd,res://tests/gut/test_world_snapshot.gd,res://tests/gut/test_package_receipts_loss.gd,res://tests/gut/test_furniture_arrival.gd' -gexit
& .bin/Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/smoke/morning_truck_smoke.tscn -- --write
& .bin/Godot_v4.7.1-stable_win64_console.exe --headless --path . res://tests/smoke/morning_truck_smoke.tscn -- restore
python utils/validate_project_structure.py
git diff --check
```

Parser выполнен через `utils/validate_district_scripts.gd` для C_Receiving, ReceivingBatch, DEF_ItemPlacement, E_MorningTruck, E_ReceivingZone, ItemPlacementSolver, ReceivingDeliveryService, ReceivingPackageFactory, SaveDataCodec, WorldSnapshotService, S_Receiving и обоих новых скриптов. Логи: `%TEMP%/truck_morning_gut_final.log`, `truck_morning_parser_final.log`, `truck_morning_smoke_write.log`, `truck_morning_smoke_restore.log`, `truck_morning_structure.log`.

### Owner QA / blockers

[Чеклист владельца](../../qa_tasks/district_truck_morning_spawn.md): PENDING_OWNER_QA. Стоянка, дверь и удобство разгрузки не проверялись визуально. Windows QA будет обновлена в итоговой интеграции этапа 4.

## Границы и владельцы

- `content/entities/car/car.tscn`, маркер стоянки основной сцены и узкий владелец lifecycle машины.
- `ReceivingDeliveryService`, `ReceivingPackageFactory`, записи поступления и прямой snapshot партии.

Применять по области: [godot-physics-4.7](../../.agents/skills/godot-physics-4.7/SKILL.md), [godot-animation-4.7](../../.agents/skills/godot-animation-4.7/SKILL.md), [save-systems](../../.agents/skills/save-systems/SKILL.md).

## Работы

- [x] Задать положение/поворот машины Marker3D уровня; грузовые места — упорядоченными экспортируемыми ссылками на маркеры внутри машины.
- [x] Утром создать один экземпляр и открыть существующую дверь; не реализовывать путь и анимацию прибытия.
- [x] Сохранить состав/лимиты реальной поставки и стабильные ID партии/заказов; долгое утро и восстановление не создают новую партию.
- [x] Создавать коробки в свободных грузовых местах через безопасный solver; при занятости продолжать по мере разгрузки. Поддержать безопасную укладку без пересечения стенок.
- [x] Публиковать поступление каждой настоящей коробки в терминал без регистрации и номера; подготовить данные для проверки разгрузки.

## Критерии завершения

- Утром появляется одна машина, открытая дверь и одна реальная партия.
- Маркеры определяют положение машины и коробок; занятость/длительное утро не дублируют груз.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.
