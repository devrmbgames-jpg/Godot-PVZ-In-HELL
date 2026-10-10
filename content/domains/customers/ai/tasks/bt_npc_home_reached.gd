@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_condition.gd"
## Проверяет фактическое прибытие к своему адресу до начала встречи.


#region Проверка состояния
func _tick(_delta: float) -> Status:
	var job: NpcHomeDelivery = NpcDeliveryScenarioService.armed_for(_actor)
	var visit: CustomerVisit = _visit()
	if job == null or visit == null or visit.definition == null:
		return FAILURE
	var destination: Vector3 = NpcPopulationQueries.position_for(job.address_id)
	var distance: float = _actor.global_position.distance_to(destination)
	return SUCCESS if distance <= visit.definition.arrival_distance else FAILURE
#endregion
