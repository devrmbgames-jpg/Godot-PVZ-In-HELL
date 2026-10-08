@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_condition.gd"
## Освещённый NPC просит укрытие; очередь снаружи обслуживает свет отдельно.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var service: C_CustomerAgent = _service()
	if service != null and service.phase in [C_CustomerAgent.Phase.QUEUED, C_CustomerAgent.Phase.WAITING_FOR_DARKNESS]:
		return FAILURE
	return SUCCESS if _awareness.light_distress and not _awareness.fleeing and CombatService.target_for(_actor) == null else FAILURE
#endregion
