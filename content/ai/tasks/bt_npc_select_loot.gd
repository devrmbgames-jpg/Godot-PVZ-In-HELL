@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Резервирует один видимый свободный предмет без присвоения посылок.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Найти добычу"):
		return FAILURE
	return SUCCESS if NpcCommunityService.choose_loot(_actor, _person) else FAILURE

#endregion
