@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Использует одну принадлежащую NPC единицу еды.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Поесть"):
		return FAILURE
	return SUCCESS if NpcCommunityService.eat_inventory(_actor) else FAILURE

#endregion
