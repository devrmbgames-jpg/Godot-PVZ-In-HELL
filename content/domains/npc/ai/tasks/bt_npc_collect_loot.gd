@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Забирает зарезервированный доступный предмет обычной передачей.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Подобрать добычу"):
		return FAILURE
	return SUCCESS if NpcCommunityService.collect_loot(_actor) else FAILURE

#endregion
