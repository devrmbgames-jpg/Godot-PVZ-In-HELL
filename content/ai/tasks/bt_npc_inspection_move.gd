@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Продолжает движение к зарезервированной кабинке или месту выдачи.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Пройти путь осмотра"):
		return FAILURE
	_move(CustomerInspectionService.destination(_actor), _visit().definition.arrival_distance)
	return RUNNING

#endregion
