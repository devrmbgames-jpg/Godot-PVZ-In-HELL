@tool
extends C_Attribute
class_name C_Health

## Inherited base is maximum HP; inherited value is current HP.
## Only S_Damage changes gameplay health. Defeat is terminal until an explicit respawn.
@export var defeated: bool = false


func _init_definition() -> void:
	definition = preload("res://content/definitions/gameplay/attributes/health.tres")
