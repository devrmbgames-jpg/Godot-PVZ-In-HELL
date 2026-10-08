extends GameDefinition
## Авторский ассортимент, расписание торговли и условия доставки покупок.
class_name DEF_TraderProfile

## Отображаемое имя торговца.
@export var display_name: String = "Торговец"
## Ассортимент определения, заменяющий прежний catalog компонента.
@export var catalog: Array[DEF_InventoryItem] = []
## Первый день торговли, начиная с 1.
@export_range(1, 365) var first_day: int = 1
## Период появления в днях относительно first_day.
@export_range(1, 365) var repeat_days: int = 1
## Битовая маска разрешённых фаз торговли.
@export_flags("Morning:1", "Day:2", "Evening:4", "Night:8") var open_phases: int = 7
## Разрешает отдельную платную доставку крупной мебели торговцем.
@export var home_delivery_enabled: bool = true
## Доплата доставки заказа в целых денежных единицах.
@export_range(0, 1000000000) var delivery_fee: int = 100
## Задержка доставки после оплаты в игровых днях.
@export_range(1, 30) var delivery_delay_days: int = 1

## Optional authored refusal quest; null disables this mechanic for this issuer.
@export var refusal_quest: DEF_RefusalQuest = null
