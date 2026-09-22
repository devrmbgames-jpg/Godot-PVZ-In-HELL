@tool
@icon("res://addons/at-icons/node3d/door.svg")
extends Entity
class_name E_Door

@export var hinge_joint: HingeJoint3D = null
@export var door_root: Node3D = null




func on_ready() -> void:
	var door: C_Door = get_component(C_Door) as C_Door
	if door :
		door.hinge_joint = hinge_joint
		door.door_root = door_root
