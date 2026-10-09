@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Проверяет услышанную позицию без чтения местоположения источника.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Проверить шум"):
		return FAILURE
	_move(_awareness.heard_position, NpcDecisionService.ARRIVAL_DISTANCE)
	return RUNNING

#endregion
