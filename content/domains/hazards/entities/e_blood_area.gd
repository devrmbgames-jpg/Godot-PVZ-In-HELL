@tool
extends E_Hazard
## Thin native blood volume access; hazard lifecycle and NPC behavior remain separate owners.
class_name E_BloodArea

@onready var _area: Area3D = $Area
@onready var _shape: CollisionShape3D = $Area/Shape
@onready var _visual: MeshInstance3D = $Visual


#region Authored volume access
## Provides actual physical candidates without scheduling or health changes.
func get_area() -> Area3D:
	return _area


## Provides the native authored collision slot for profile configuration.
func get_shape() -> CollisionShape3D:
	return _shape


## Provides the authored spill mesh slot for profile configuration.
func get_visual() -> MeshInstance3D:
	return _visual
#endregion
