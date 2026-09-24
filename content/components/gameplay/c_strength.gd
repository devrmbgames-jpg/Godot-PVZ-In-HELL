@tool
extends C_Attribute
## Physical carrying strength used by generic Carry load limits and slowdown.
class_name C_Strength


func _init(new_val: float = 1.0) -> void:
	_init_definition()
	base = new_val
	value = new_val


func _init_definition() -> void:
	definition = preload("res://content/definitions/gameplay/attributes/def_attr_strength.tres")
