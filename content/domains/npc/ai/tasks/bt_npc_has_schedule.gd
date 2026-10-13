@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Проверяет незавершённую обязательную цель фазы.


#region Проверка состояния
func _tick(_delta: float) -> Status:
	var waiting: bool = NpcScheduleRules.waiting_at_home(
		NpcPopulationQueries.current(),
		_person,
		_person.planned_day,
		_person.planned_phase as C_DayCycle.Phase,
	)
	return SUCCESS if not _person.phase_complete or waiting else FAILURE
#endregion
