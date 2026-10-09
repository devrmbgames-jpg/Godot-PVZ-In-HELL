# Торговец — дневная торговля и выбор доставки мебели

Status: **DONE**

Родительский этап: [Лут и торговля](district_loot_commerce.md). Порядок выполнения: [общая задача](district_service_update.md).

Зависимости: [Предметы — безопасный дроп и ожидающий остаток](district_safe_loot_placement.md).

## Task state

### Goal

Разрешить услуги торговца во все игровые фазы и предложить доставку только явно отмеченной крупной мебели.

### Current

Профиль постоянного торговца и прежний C_Trader без профиля доступны MORNING/DAY/EVENING; NIGHT запрещён. Его авторское расписание явно задаёт STREET во всех трёх фазах и сохраняет одну личность у торговой точки. Другие профили сохраняют авторские ограничения дней/фаз.

Добавлен `DEF_InventoryItem.bulky_furniture`, явно включённый у большой полки. `TraderCatalogService.can_deliver` и `CommerceService.home_delivery` требуют одновременно FURNITURE, этот признак и разрешение профиля; еда/аптечки/упаковка не доставляются торговцем. Стартовая доплата — 100$.

Кнопка мебели открывает отдельный ConfirmationDialog с выбором «Сам», «Доставить +100$» и отменой. Один ID связывает выбранный способ с чеком, кошельком и PendingDelivery. До ответа денег/заказа нет; ответ очищает временный запрос до побочных эффектов, повторно проверяет участников и баланс. Самовывоз сохраняет физическую выдачу у торговца; доставка сохраняет заказ на следующее утро. Отмена возвращает фокус магазину, закрытие освобождает единственный модальный токен. Изменения уровня и навигации не требовались. Физическая выдача на новой площадке около ПВЗ относится к следующей задаче; родительский этап ещё не завершён.

### Validation

Фактически выполнено 2026-10-06:

- GUT: **48/48 PASS, 464 assertions, 5 scripts**, exit 0. `test_trader_purchase` включает прежние физические регрессии `test_trader_furniture`. Проверены три торговые фазы и NIGHT, фактическое расписание постоянного торговца, отдельные профили, ограничения доставки в сервисе, самовывоз, отмена/Back, единственный захват, повторные ответы, смена баланса, отключение/смерть/удаление продавца и round-trip оплаченного заказа.
- Godot parser: **10 checked, 0 failed**, exit 0; все изменённые .gd, включая тесты и smoke. Новых ошибок/предупреждений скриптов в свежем процессе нет.
- Связный headless smoke полного `main_level`: **write PASS / restore PASS**, exit 0 обоих процессов. Настоящий игрок покупает полку через кнопки/попап днём; отмена не платит, повторный ответ не создаёт второй чек. Снимок валидируется и восстанавливается в новом процессе с одной оплатой 280$, одним ID и заказом на утро дня 2.
- `git diff --check`: PASS. Структура: FAIL только на **30 прежних ошибках шести неизменённых `agent_tasks/r26_*`** (нет обязательных блоков состояния); собственных ошибок нет.
- Live MCP использован для записи и диагностики. Тестовые скрипты диагностируются чисто; пять глобальных классов возвращают fallback `gdscript_reload_failed` code 43 без конкретного сообщения даже при повторной записи того же текста. Чистую live-проверку этих классов не заявляем; независимый parser и реальные GUT/smoke их успешно загружают. В текущем редакторе также уже была прежняя ошибка `MISSED_REGISTRATION` в неизменённом `unregistered_loss_smoke.gd`. Редактор владельца не перезапускался.
- Windows-процессы выводят прежнюю ошибку чтения root certificate store до запуска проекта; результаты и exit codes выше получены после неё. Отрисовка и визуальная приёмка не запускались.

Команды (движок `.bin/Godot_v4.7.1-stable_win64_console.exe`):

```powershell
--headless --path . -s addons/gut/gut_cmdln.gd '-gtest=res://tests/gut/test_trader_purchase.gd,res://tests/gut/test_commerce.gd,res://tests/gut/test_district_population.gd,res://tests/gut/test_world_snapshot.gd,res://tests/gut/test_save_data.gd' -gexit
--headless --path . -s utils/validate_district_scripts.gd -- res://content/definitions/gameplay/inventory/def_inventory_item.gd res://content/definitions/gameplay/commerce/def_trader_profile.gd res://content/services/commerce/trader_catalog_service.gd res://content/services/commerce/commerce_service.gd res://content/ui/commerce_panel.gd res://tests/gut/test_trader_purchase.gd res://tests/gut/test_trader_furniture.gd res://tests/gut/test_commerce.gd res://tests/gut/test_district_population.gd res://tests/smoke/trader_purchase_smoke.gd
--headless --path . res://tests/smoke/trader_purchase_smoke.tscn
--headless --path . res://tests/smoke/trader_purchase_smoke.tscn -- restore
python utils/validate_project_structure.py
```

Логи: `%TEMP%/trader_purchase_gut_final.log`, `trader_purchase_parser_final.log`, `trader_purchase_smoke_write.log`, `trader_purchase_smoke_restore.log`, `trader_purchase_structure.log`. Первый GUT прогон выявил неверное имя метода в тесте и конфликт ограничения одного клика за кадр с отдельным ответом попапа; исправлены до итогового PASS. Smoke использует только собственный `user://trader_purchase_smoke.pvzh` и удаляет его после восстановления.

### Owner QA / blockers

Внешний вид, клавиатурная навигация и восстановление управления: [ручной чеклист](../qa_tasks/district_trader_purchase.md), PENDING_OWNER_QA. Блокеров реализации этой небольшой задачи нет; live fallback описан выше как ограничение диагностики текущего редактора.

## Границы и владельцы

- `DEF_TraderProfile`, `DEF_InventoryItem`, `TraderCatalogService` и расписание постоянного торговца.
- `content/services/commerce/commerce_service.gd`, `content/ui/commerce_panel.gd` и контракт `PendingDelivery`.

Применять по области: [game-ui-ux](../.agents/skills/game-ui-ux/SKILL.md), [save-systems](../.agents/skills/save-systems/SKILL.md).

## Работы

- [x] Разрешить торговлю MORNING/DAY/EVENING; технический NIGHT сна не открывает магазин. Согласовать фактическое расписание торговца.
- [x] Доставку разрешать только мебели с авторским признаком крупногабаритности; проверять это в сервисе покупки.
- [x] Показывать отдельный попап «Доставить или заберёшь сам?» с ответами «Сам» / «Доставить +100$».
- [x] Отмена не списывает деньги; самовывоз сохраняет текущий способ выдачи. Доставка однократно оплачивает предмет и 100$ и сохраняет заказ на следующее утро.
- [x] Повторный ответ, закрытие UI, нехватка денег и исчезновение продавца не создают дублей; корректно освобождать фокус и управление.

## Критерии завершения

- Живой торговец доступен утром, днём и вечером; еда/аптечки не предлагают доставку.
- Выбор самовывоза/доставки фиксирует одну покупку; отмена и недостаток денег не меняют баланс.

Выполнять только этот ограниченный результат, объединяя связанные чтения, правки и проверки. Не расширять задачу соседними функциями. Закрыть её собственные Status/Current/Validation, сохранить связный результат коммитом и обновить следующее действие в общей задаче. Завершение этой задачи само по себе не закрывает родительский этап.
