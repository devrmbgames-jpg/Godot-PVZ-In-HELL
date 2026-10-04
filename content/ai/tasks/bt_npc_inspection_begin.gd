@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Начинает осмотр после физического достижения кабинки.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Осмотр в кабинке"):
		return FAILURE
	CustomerInspectionService.arrive(_actor)
	return SUCCESS

#endregion
