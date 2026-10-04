@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Существующая роль обслуживания выбирается раньше расписания.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if _actor.has_component(C_CustomerAgent) else FAILURE
#endregion
