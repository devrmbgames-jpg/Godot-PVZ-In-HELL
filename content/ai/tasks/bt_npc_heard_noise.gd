@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Проверка анонимного шума не раскрывает текущую позицию источника.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if _awareness.heard_remaining > 0.0 and _awareness.investigate_noise else FAILURE
#endregion
