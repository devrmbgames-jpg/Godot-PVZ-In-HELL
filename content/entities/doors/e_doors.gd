@tool
@icon("res://addons/at-icons/node3d/door.svg")
extends Entity
class_name E_Door

## Scene glue stays on the Entity; gameplay state belongs in C_Door when authored.
@export var hinge_joint: HingeJoint3D = null
@export var door_root: Node3D = null
