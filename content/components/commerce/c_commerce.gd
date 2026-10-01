extends Component
## Session-owned persistent commerce records; CommerceService is the write boundary.
class_name C_Commerce

@export var receipts: Array[PurchaseReceipt] = []
@export var pending_deliveries: Array[PendingDelivery] = []
@export var catalog: Array[DEF_InventoryItem] = [preload("res://content/definitions/gameplay/inventory/def_item_food.tres"), preload("res://content/definitions/gameplay/inventory/def_item_med.tres"), preload("res://content/definitions/gameplay/inventory/def_item_bubble_wrap.tres")]
@export var next_request: int = 0
var transaction_in_progress: bool = false
