@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Преследует только подтверждённую восприятием позицию.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Преследование"):
		return FAILURE
	_move(_awareness.last_seen_position, NpcDecisionService.COMBAT_STOP_DISTANCE)
	return RUNNING

#endregion
