@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Запрашивает одно мотивированное нападение с лимитом фазы.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Проверить повод для нападения"):
		return FAILURE
	return SUCCESS if NpcCommunityService.try_conflict(_actor, _person) else FAILURE

#endregion
