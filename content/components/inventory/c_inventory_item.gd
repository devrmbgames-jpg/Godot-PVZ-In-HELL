extends Component
class_name C_InventoryItem

@export var definition: DEF_InventoryItem = null
@export var quantity: int = 1
var transfer_in_progress: bool = false
var pending_use_id: StringName = &""
