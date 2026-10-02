extends Component
class_name C_Trader

@export var trader_key: StringName = &"evening_trader"
@export var catalog: Array[DEF_InventoryItem] = []
## Optional profile supersedes legacy catalog; existing scenes remain compatible.
@export var profile: DEF_TraderProfile = null
@export var furniture_pickup_path: NodePath = NodePath("FurniturePickup")
