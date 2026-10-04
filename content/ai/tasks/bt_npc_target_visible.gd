@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Использует подготовленное зрение текущего такта.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if _awareness.target_visible else FAILURE
#endregion
