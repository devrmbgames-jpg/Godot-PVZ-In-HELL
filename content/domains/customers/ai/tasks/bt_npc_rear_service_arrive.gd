@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_action.gd"
## Commits ordinary service arrival at the rear contact without revealing the order unseen.


#region Explicit arrival
func _tick(_delta: float) -> Status:
	if not _claim("Жуткий: прибыл к месту контакта"):
		return FAILURE
	return SUCCESS if CustomerStalkingService.arrive(_actor) else FAILURE
#endregion
