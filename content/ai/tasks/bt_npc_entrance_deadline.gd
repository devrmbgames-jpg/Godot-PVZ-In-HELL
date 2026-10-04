@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Конечное ожидание света считается после приближения к входу.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var service: C_CustomerAgent = _service()
	return SUCCESS if service != null and service.entrance_wait_elapsed >= DistrictPopulationService.current().definition.service_wait_timeout else FAILURE
#endregion
