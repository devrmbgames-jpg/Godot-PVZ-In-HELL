extends GameDefinition
class_name DEF_CustomerSchedule

@export var supply: DEF_Delivery = preload(
	"res://content/definitions/gameplay/deliveries/def_delivery_morning_supply.tres"
)
@export var events: Array[DEF_CustomerEvent] = []
@export var customer_scene: PackedScene = null
