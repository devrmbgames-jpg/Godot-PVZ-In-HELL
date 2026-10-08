@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_condition.gd"
## Домашняя встреча сохраняет связь с конкретным адресом.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if HomeMeetingQueries.meeting_for(_actor) != null else FAILURE
#endregion
