@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Продолжает уже назначенный путь без нового планирования.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Прогулка"):
		return FAILURE
	_own_movement()
	return RUNNING

#endregion
