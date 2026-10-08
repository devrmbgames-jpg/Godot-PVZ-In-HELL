@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Фиксирует однократный исход домашней доставки через её сервис.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Завершить доставку"):
		return FAILURE
	return SUCCESS if NpcHomeDeliveryService.complete(HomeMeetingQueries.meeting_for(_actor)) else FAILURE

#endregion
