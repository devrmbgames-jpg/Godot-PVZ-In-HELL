@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Запрашивает движение к авторскому тёмному укрытию.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Укрыться от света"):
		return FAILURE
	_move(NpcTraitService.dark_refuge(_actor, _person), NpcDecisionService.ARRIVAL_DISTANCE)
	return RUNNING

#endregion
