@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Фиксирует физическое прибытие получателя.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Получатель прибыл"):
		return FAILURE
	NpcServiceRole.arrive(_actor)
	return SUCCESS

#endregion
