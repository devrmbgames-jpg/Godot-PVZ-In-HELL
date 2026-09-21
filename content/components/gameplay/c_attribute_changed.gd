@tool
extends C_Attribute
class_name C_AttributeChanged

## Текущее значение
@export var current := 100.0 :
	set = _set_current


func _set_current(new_value: float) -> void :
	var old_value := current
	current = new_value
	assert(definition)
	if definition.has_emit_changes_enabled :
		property_changed.emit(self, definition.key_current, old_value, new_value)
	


func _init(new_val: float = 100.0, current_val: float = -10000) -> void:
	_init_definition()
	base = new_val
	value = new_val
	if current_val > -10000 :
		current = new_val
	else :
		current = current_val
