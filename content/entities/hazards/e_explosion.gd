@tool
extends E_Hazard
## Independent blast scene identity and its presentation child; no HP/impulse authority.
class_name E_Explosion

@onready var _visual: MeshInstance3D = $Visual
@onready var _spatial: Node3D = self as Node as Node3D


func get_visual() -> MeshInstance3D:
	return _visual


func get_spatial() -> Node3D:
	return _spatial
