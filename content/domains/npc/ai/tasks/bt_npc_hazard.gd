@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Наблюдает непосредственный риск эффективного урона.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if _awareness.hazard_distress else FAILURE
#endregion
