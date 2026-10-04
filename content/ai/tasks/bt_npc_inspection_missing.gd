@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Отсутствие зарезервированной коробки требует завершения осмотра.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if CustomerInspectionService.parcel_for(_actor) == null else FAILURE
#endregion
