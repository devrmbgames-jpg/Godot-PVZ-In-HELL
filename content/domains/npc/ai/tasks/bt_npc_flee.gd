@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Двигается к один раз выбранному выходу и завершает уход у прохода.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Бегство"):
		return FAILURE
	_own_movement()
	return SUCCESS if NpcDecisionService.flee(_actor, _person, _awareness) else RUNNING

#endregion
