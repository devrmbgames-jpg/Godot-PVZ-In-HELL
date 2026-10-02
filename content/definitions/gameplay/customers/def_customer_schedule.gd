extends GameDefinition
class_name DEF_CustomerSchedule

@export var supply: DEF_Delivery = preload(
	"res://content/definitions/gameplay/deliveries/def_delivery_morning_supply.tres"
)
@export var events: Array[DEF_CustomerEvent] = []
@export var customer_scene: PackedScene = null
## Gap starts after physical departure/death, not while the previous NPC is still present.
@export_range(0.0, 600.0, 1.0, "or_greater") var arrival_interval_seconds: float = 30.0
