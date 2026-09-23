@tool
extends C_AttributeChanged
## Shared HP authority for living actors, packages and destructible props.
class_name C_Health

## Inherited value is computed maximum HP; inherited current is remaining HP.
## Only O_Damage changes gameplay health. Depletion is terminal until an explicit respawn.
@export var depleted: bool = false


func _init_definition() -> void:
	definition = preload("res://content/definitions/gameplay/attributes/def_attr_health.tres")

# обертки во круг API


func get_hp_max() -> float:
	return value


func get_hp_current() -> float:
	return current


func set_hp_current(val: float) -> void:
	current = val
