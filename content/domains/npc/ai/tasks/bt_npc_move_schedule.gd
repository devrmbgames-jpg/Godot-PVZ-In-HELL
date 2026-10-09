@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Выполняет движение к стабильному ID цели расписания.


#region Листовое действие
func _tick(_delta: float) -> Status:
	if not _claim("Расписание"):
		return FAILURE
	var generation: int = NpcScheduleActionService.accept_schedule(_actor, _person)
	if not NpcScheduleActionService.schedule_target_available(_person):
		NpcScheduleActionService.finish_schedule(_actor, generation, false, &"target_unavailable")
		return FAILURE
	if not NpcScheduleActionService.start_schedule(_actor, generation):
		return FAILURE
	_move(
		NpcPopulationQueries.position_for(_person.goal_id),
		NpcDecisionService.schedule_distance(_person),
	)
	return RUNNING

#endregion
