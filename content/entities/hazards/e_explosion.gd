@tool
extends E_Hazard
## Independent blast scene identity and its presentation child; no HP/impulse authority.
class_name E_Explosion

@onready var visual: MeshInstance3D = $Visual
@onready var spatial: Node3D = self as Node as Node3D
