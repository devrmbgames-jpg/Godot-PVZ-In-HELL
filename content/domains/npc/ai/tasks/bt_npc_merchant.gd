@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Местный торговец остаётся на своей рабочей точке.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if _person.profile.merchant else FAILURE
#endregion
