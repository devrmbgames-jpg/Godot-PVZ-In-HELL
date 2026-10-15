@tool
extends Component
## Значения атрибута с setter-уведомлениями; вычисления и диапазон задаёт domain writer.
## Сам Component не применяет модификаторы и не ограничивает записанные числа.
class_name C_Attribute

## Ключи уведомлений; наследник задаёт ресурс до начальных setter.
@export var definition: DEF_Attribute = null

## Базовое значение в единицах наследника; definition обязателен до вызова setter.
@export var base := 100.0:
	set = _set_base

## Значение, вычисленное domain writer; изменение base само его не пересчитывает.
@export var value := 100.0:
	set = _set_value

var _transaction_depth: int = 0
var _pending_changes: Array[Dictionary] = []


#region Atomic attribute notifications
## Nestable notification scope for this Component only; setters still write fields immediately.
## The caller owns cross-field/domain ordering; this operation provides no rollback.
func begin_transaction() -> void:
	_transaction_depth += 1


## Requires a matching begin; the outermost end emits captured changes synchronously in order.
## Subscribers may reenter; other Components are outside this notification scope.
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
