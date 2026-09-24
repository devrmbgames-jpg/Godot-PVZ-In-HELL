@tool
extends Entity
## Independent blast scene identity and its presentation child; no HP/impulse authority.
class_name E_Explosion

## Own-child placeholder visualization.
@onready var visual: MeshInstance3D = $Visual

## GECS Entity extends Node; this prefab is hosted by a nonphysical Node3D.
@onready var spatial: Node3D = self as Node as Node3D
