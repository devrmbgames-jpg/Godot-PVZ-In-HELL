@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Сообщает заказ через существующую политику знакомства.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Приветствие"):
		return FAILURE
	CustomerFlowService.greet(_actor)
	return SUCCESS

#endregion
