extends Resource
## Durable paid operation; never stores live Entity references.
class_name PurchaseReceipt

enum Mode { PURCHASE, ORDER }
@export var operation_id: StringName = &""
@export var mode: Mode = Mode.PURCHASE
@export var item_key: StringName = &""
@export var quantity: int = 1
@export var total_price: int = 0
@export var day_index: int = 1
