@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Фиксирует достигнутую обязательную точку расписания.

var _completion: NpcScheduleCompletionRequest = null


#region Листовое действие
func _enter() -> void:
	super._enter()
	_completion = null


func _tick(_delta: float) -> Status:
	if not _claim("Расписание выполнено"):
		return FAILURE
	if (
		_person.phase_complete
		and NpcScheduleRules.waiting_at_home(
			NpcPopulationQueries.current(),
			_person,
			_person.planned_day,
			_person.planned_phase as C_DayCycle.Phase,
		)
	):
		_own_movement()
		NpcIntentArbiter.stop(_actor, intent_owner)
		return RUNNING
	if _completion == null:
		var generation: int = NpcScheduleActionService.accept_schedule(_actor, _person)
		if not NpcScheduleActionService.start_schedule(_actor, generation):
			return FAILURE
		_completion = NpcScheduleActionService.request_phase_completion(_actor)
	if not _completion.completed:
		return RUNNING
	return SUCCESS if _completion.succeeded else FAILURE

#endregion
