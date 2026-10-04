@tool
extends "res://content/ai/tasks/bt_npc_action.gd"
## Выполняет движение к стабильному ID цели расписания.

#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Расписание"):
		return FAILURE
	_move(DistrictPopulationService.position_for(_person.goal_id), NpcDecisionService.schedule_distance(_person))
	return RUNNING

#endregion
