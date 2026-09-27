@tool
extends E_Hazard
## Owns the toxic prefab's Area3D handles; gameplay timing and HP remain in processors.
class_name E_ToxicArea

@onready var _area: Area3D = $Area
@onready var _shape: CollisionShape3D = $Area/Shape
@onready var _visual: MeshInstance3D = $Visual


func get_area() -> Area3D:
	return _area


func get_shape() -> CollisionShape3D:
	return _shape


func get_visual() -> MeshInstance3D:
	return _visual
