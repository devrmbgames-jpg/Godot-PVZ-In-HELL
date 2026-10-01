@tool
extends Entity
## Engine-only presentation of a world pickup. OwnedBy determines whether it is visible/collidable.
class_name E_InventoryPickup

var _world_layer: int = 0
var _world_mask: int = 0
var _owned: bool = false
@onready var _body: StaticBody3D = self as Node as StaticBody3D
@onready var _visual: Node3D = $Visual
@onready var _caption: Label3D = $Visual/Caption


func _ready() -> void:
	_world_layer = _body.collision_layer
	_world_mask = _body.collision_mask


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var state: C_InventoryItem = get_component(C_InventoryItem) as C_InventoryItem
	if state != null and state.definition != null:
		_caption.text = "%s ×%d" % [state.definition.display_name, state.quantity]
	var owned: bool = InventoryService.owner_for(self) != null
	if owned == _owned:
		return
	_owned = owned
	_visual.visible = not owned
	_body.collision_layer = 0 if owned else _world_layer
	_body.collision_mask = 0 if owned else _world_mask
	var interactable: C_Interactable = get_component(C_Interactable) as C_Interactable
	if interactable != null:
		interactable.enabled = not owned
