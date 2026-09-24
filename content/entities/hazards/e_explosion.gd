@tool
extends Entity
## Independent blast scene identity and its presentation child; no HP/impulse authority.
class_name E_Explosion

## Own-child placeholder visualization.
@onready var visual: MeshInstance3D = $Visual
