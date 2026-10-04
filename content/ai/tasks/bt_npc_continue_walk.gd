@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Продолжает уже назначенный путь без нового планирования.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Прогулка"):
		return FAILURE
	_owns_movement = true
	return RUNNING

#endregion
