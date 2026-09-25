@tool
extends E_Hazard
## Owns the toxic prefab's Area3D handles; gameplay timing and HP remain in processors.
class_name E_ToxicArea

@onready var area: Area3D = $Area
@onready var shape: CollisionShape3D = $Area/Shape
@onready var visual: MeshInstance3D = $Visual
