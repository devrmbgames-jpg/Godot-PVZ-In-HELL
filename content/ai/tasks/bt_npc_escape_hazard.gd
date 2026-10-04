@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Запрашивает единственный выход из эффективной опасности.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Выйти из опасной зоны"):
		return FAILURE
	_move(NpcRouteService.refuge(_actor), NpcDecisionService.ARRIVAL_DISTANCE)
	return RUNNING

#endregion
