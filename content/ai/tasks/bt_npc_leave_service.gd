@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Запрашивает уход с сохранением исхода конкретного заказа.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Завершить обслуживание"):
		return FAILURE
	CustomerFlowService.leave_service(_actor, _visit())
	return SUCCESS

#endregion
