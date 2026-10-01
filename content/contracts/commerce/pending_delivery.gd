extends Resource
class_name PendingDelivery

@export var delivery_id: StringName = &""
@export var item: DEF_InventoryItem = null
@export var quantity: int = 1
@export var ordered_day: int = 1
@export var delivery_day: int = 2
@export var fulfilled: bool = false
