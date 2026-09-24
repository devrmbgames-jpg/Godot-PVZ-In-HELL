@tool
extends Entity
## Owns the toxic prefab's Area3D handles; gameplay timing and HP remain in processors.
class_name E_ToxicArea

## Own-child spatial handles configured from immutable hazard data.
@onready var area: Area3D = $Area
@onready var shape: CollisionShape3D = $Area/Shape
@onready var visual: MeshInstance3D = $Visual
