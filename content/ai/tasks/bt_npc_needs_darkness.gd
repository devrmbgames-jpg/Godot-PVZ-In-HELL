@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Вход учитывает логическое состояние света, независимо от мерцания.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcServiceRole.needs_darkness(_actor) else FAILURE
#endregion
