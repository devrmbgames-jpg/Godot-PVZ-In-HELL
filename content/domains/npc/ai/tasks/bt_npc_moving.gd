@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Проверяет незавершённое ранее назначенное движение.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var intent: C_NpcIntent = _intent()
	return SUCCESS if intent.movement_active and not intent.arrived else FAILURE
#endregion
