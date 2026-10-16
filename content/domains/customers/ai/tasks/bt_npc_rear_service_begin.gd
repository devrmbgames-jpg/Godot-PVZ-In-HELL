@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Consumes at most one rear-service choice for this physical appearance.


#region Explicit role strategy
func _tick(_delta: float) -> Status:
	if not _claim("Жуткий: выбор сервисного обхода"):
		return FAILURE
	return SUCCESS if CustomerStalkingService.begin(_actor) else FAILURE
#endregion
