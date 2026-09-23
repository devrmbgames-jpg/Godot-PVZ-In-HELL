@tool
extends C_Attribute
## Shared HP authority for living actors, packages and destructible props.
class_name C_Health

## Inherited base is maximum HP; inherited value is current HP.
## Only S_Damage changes gameplay health. Depletion is terminal until an explicit respawn.
@export var depleted: bool = false


func _init_definition() -> void:
	definition = preload("res://content/definitions/gameplay/attributes/def_attr_health.tres")
