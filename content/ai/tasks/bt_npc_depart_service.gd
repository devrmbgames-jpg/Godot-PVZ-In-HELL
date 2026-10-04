@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Идёт от стойки к авторской точке выхода посетителей.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Уход от стойки"):
		return FAILURE
	_move(CustomerFlowService.counter().entry_position(), _visit().definition.arrival_distance)
	return RUNNING

#endregion
