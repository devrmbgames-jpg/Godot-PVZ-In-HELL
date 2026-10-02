@tool
@icon("res://addons/at-icons/node3d/door.svg")
extends E_Openable
class_name E_Door

## Existing door scene node paths are retained; C_Openable is the sole lock/motion authority.

var _leaf_broken: bool = false
var _initial_root_layer: int = 0
var _initial_leaf_layer: int = 0
var _initial_leaf_mask: int = 0
var _initial_leaf_freeze: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_initial_root_layer = (self as Node as CollisionObject3D).collision_layer
	if is_instance_valid(door_root):
		_initial_leaf_layer = door_root.collision_layer
		_initial_leaf_mask = door_root.collision_mask
		_initial_leaf_freeze = door_root.freeze


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	sync_destruction_view()
	if not _leaf_broken:
		super._physics_process(delta)


## Engine presentation/collision glue. The depleted Health tombstone remains saveable.
func sync_destruction_view() -> void:
	var config: C_BreakableDoor = get_component(C_BreakableDoor) as C_BreakableDoor
	var health: C_Health = get_component(C_Health) as C_Health
	if config == null or health == null or not is_instance_valid(door_root):
		return
	var broken: bool = health.depleted
	var status: Label3D = get_node_or_null("BreakageStatus") as Label3D
	if status != null:
		status.visible = DebugHudService.is_enabled()
		status.text = "%s · HP %.0f/%.0f\n%s" % [
			"Замок" if config.mode == C_BreakableDoor.Mode.PADLOCK else "Дверь",
			health.get_hp_current(), health.get_hp_max(),
			"Разрушено" if broken else "Ударьте ножом или молотком",
		]
	if config.mode == C_BreakableDoor.Mode.PADLOCK:
		var padlock: Node3D = door_root.get_node_or_null("Padlock") as Node3D
		if padlock != null:
			padlock.visible = not broken
		return
	if _leaf_broken == broken:
		return
	_leaf_broken = broken
	(self as Node as CollisionObject3D).collision_layer = 0 if broken else _initial_root_layer
	door_root.collision_layer = 0 if broken else _initial_leaf_layer
	door_root.collision_mask = 0 if broken else _initial_leaf_mask
	door_root.freeze = true if broken else _initial_leaf_freeze
	door_root.visible = not broken
	if broken and is_instance_valid(hinge_joint):
		hinge_joint.set("motor/enable", false)


func strike_point() -> Vector3:
	var config: C_BreakableDoor = get_component(C_BreakableDoor) as C_BreakableDoor
	var aim: Node3D = get_node_or_null("ColInteract") as Node3D
	if config != null and config.mode == C_BreakableDoor.Mode.PADLOCK and is_instance_valid(door_root):
		aim = door_root.get_node_or_null("Padlock") as Node3D
	return aim.global_position if aim != null else (self as Node as Node3D).global_position
