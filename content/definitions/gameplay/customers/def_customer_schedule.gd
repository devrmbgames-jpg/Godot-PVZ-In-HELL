extends GameDefinition
class_name DEF_CustomerSchedule

@export var supply: DEF_Delivery = null
@export var events: Array[DEF_CustomerEvent] = []
@export var customer_scene: PackedScene = null
## Gap starts after physical departure/death, not while the previous NPC is still present.
@export_range(0.0, 600.0, 1.0, "or_greater") var arrival_interval_seconds: float = 30.0


func _init() -> void:
	# Supply содержит физические сцены: загрузка при создании ресурса разрывает
	# compile-time цикл Schedule → сцена предмета → Grab/CustomerFlow → Schedule.
	supply = load("res://content/definitions/gameplay/deliveries/def_delivery_morning_supply.tres") as DEF_Delivery
