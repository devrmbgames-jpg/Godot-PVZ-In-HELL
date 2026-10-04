@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Ждёт окончание выполняемого физическим исполнителем удара.

#region Листовое действие
func _tick(_delta: float) -> Status:
	return RUNNING if _claim("Исполнение атаки") else FAILURE

#endregion
