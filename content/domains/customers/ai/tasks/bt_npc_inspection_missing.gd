@tool
extends "res://content/domains/customers/ai/tasks/bt_customer_condition.gd"
## Отсутствие зарезервированной коробки требует завершения осмотра.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if CustomerInspectionQueries.parcel_for(_actor) == null else FAILURE
#endregion
