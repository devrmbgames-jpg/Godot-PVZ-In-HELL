@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Проверяет незавершённую обязательную цель фазы.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if not _person.phase_complete else FAILURE
#endregion
