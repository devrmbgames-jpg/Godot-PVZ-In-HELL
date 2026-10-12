@tool
extends Component
## Базовое и вычисленное значение атрибута с опциональными GECS-уведомлениями.
class_name C_Attribute

## Ключи уведомлений; наследник задаёт ресурс до начальных setter.
@export var definition: DEF_Attribute = null

## Базовое значение атрибута
@export var base := 100.0:
	set = _set_base

## Вычисленное значение атрибута с учётом модификаторов.
@export var value := 100.0:
	set = _set_value

var _transaction_depth: int = 0
var _pending_changes: Array[Dictionary] = []


#region Atomic attribute notifications
## Delays setter notifications until every attribute in an explicit transaction is committed.
func begin_transaction() -> void:
	_transaction_depth += 1


## Publishes captured changes only after the outermost transaction has committed its state.
func end_transaction() -> void:
	assert(_transaction_depth > 0)
	_transaction_depth -= 1
	if _transaction_depth > 0:
		return
	var changes: Array[Dictionary] = _pending_changes
	_pending_changes = []
	for change: Dictionary in changes:
		property_changed.emit(self, change.key, change.previous, change.current)


func _notify_change(key: StringName, previous: float, updated: float) -> void:
	if not definition.has_emit_changes_enabled:
		return
	if _transaction_depth > 0:
		_pending_changes.append({ "key": key, "previous": previous, "current": updated })
	else:
		property_changed.emit(self, key, previous, updated)
#endregion


#region Запись и инициализация атрибута
func _set_base(new_value: float) -> void:
	var old_value = base
	base = new_value
	assert(definition)
	_notify_change(definition.key_base, old_value, new_value)


func _set_value(new_value: float) -> void:
	var old_value = value
	value = new_value
	assert(definition)
	_notify_change(definition.key_value, old_value, new_value)


## Наследник задаёт definition до записи начальных значений конструктора.
func _init_definition() -> void:
	pass


func _init(new_val: float = 100.0) -> void:
	_init_definition()
	base = new_val
	value = new_val

#endregion
