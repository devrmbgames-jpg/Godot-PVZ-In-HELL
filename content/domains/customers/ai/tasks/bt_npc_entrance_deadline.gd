@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_condition.gd"
## Конечное ожидание света считается после приближения к входу.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var service: C_CustomerAgent = _service()
	return SUCCESS if service != null and service.entrance_wait_elapsed >= NpcPopulationQueries.current().definition.service_wait_timeout else FAILURE
#endregion
