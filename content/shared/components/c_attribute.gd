@tool
extends Component
## Базовое и вычисленное значение атрибута с опциональными GECS-уведомлениями.
class_name C_Attribute


## Ключи уведомлений; наследник задаёт ресурс до начальных setter.
@export var definition: DEF_Attribute = null

## Базовое значение атрибута
@export var base := 100.0 :
	set = _set_base

## Вычисленное значение атрибута с учётом модификаторов.
@export var value := 100.0 :
	set = _set_value


#region Запись и инициализация атрибута
func _set_base(new_value: float) -> void :
	var old_value = base
	base = new_value
	assert(definition)
	if definition.has_emit_changes_enabled :
		property_changed.emit(self, definition.key_base, old_value, new_value)

func _set_value(new_value: float) -> void :
	var old_value = value
	value = new_value
	assert(definition)
	if definition.has_emit_changes_enabled :
		property_changed.emit(self, definition.key_value, old_value, new_value)

## Наследник задаёт definition до записи начальных значений конструктора.
func _init_definition() -> void :
	pass

func _init(new_val: float = 100.0) -> void:
	_init_definition()
	base = new_val
	value = new_val

#endregion
