@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Фиксирует достигнутую обязательную точку расписания.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Расписание выполнено"):
		return FAILURE
	DistrictPopulationService.complete_phase(_person, _actor)
	return SUCCESS

#endregion
