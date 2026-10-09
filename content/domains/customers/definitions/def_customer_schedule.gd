extends GameDefinition
## Ассортимент и правила визитов; район назначает заказы реально прибывшим коробкам.
class_name DEF_CustomerSchedule

## Общая авторская поставка, связывающая ключи событий с определениями коробок.
@export var supply: DEF_Delivery = null
## Политики обслуживания и задержки визита для видов коробок.
@export var events: Array[DEF_CustomerEvent] = []
## Общая сцена старого клиента; постоянное тело жителя создаёт население района.
@export var customer_scene: PackedScene = null
## Пауза до следующего получателя после завершения визита или смерти, в секундах.
@export_range(0.0, 600.0, 1.0, "or_greater") var arrival_interval_seconds: float = 30.0

#region Создание ресурса
func _init() -> void:
	# Supply содержит физические сцены: загрузка при создании ресурса разрывает
	# compile-time цикл Schedule → сцена предмета → Grab/CustomerFlow → Schedule.
	supply = load("res://content/domains/packages/definitions/def_delivery_morning_supply.tres") as DEF_Delivery
#endregion
