@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Наблюдает результат физического исполнителя движения.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var intent: C_NpcIntent = _intent()
	return SUCCESS if intent != null and intent.arrived else FAILURE
#endregion
