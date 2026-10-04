@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Домашняя встреча сохраняет связь с конкретным адресом.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcHomeDeliveryService.meeting_for(_actor) != null else FAILURE
#endregion
