@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Идёт от стойки к авторской точке выхода посетителей.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Уход от стойки"):
		return FAILURE
	_move(CustomerFlowQueries.counter().entry_position(), _visit().definition.arrival_distance)
	return RUNNING

#endregion
