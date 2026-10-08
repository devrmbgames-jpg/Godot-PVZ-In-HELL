@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Читает уже обновлённое зрение без дополнительных лучей или поиска источников света.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if _awareness != null and _awareness.player_visible else FAILURE
#endregion
