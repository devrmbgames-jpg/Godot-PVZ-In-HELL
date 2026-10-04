@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Фиксирует однократный исход домашней доставки через её сервис.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Завершить доставку"):
		return FAILURE
	return SUCCESS if NpcHomeDeliveryService.complete(NpcHomeDeliveryService.meeting_for(_actor)) else FAILURE

#endregion
