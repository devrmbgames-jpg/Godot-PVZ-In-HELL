@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Домашняя выдача завершает только подтверждённый физический исход.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var visit: CustomerVisit = _visit()
	return SUCCESS if visit != null and visit.actual in [CustomerVisit.Actual.DELIVERED, CustomerVisit.Actual.CUSTOMER_REFUSED] else FAILURE
#endregion
