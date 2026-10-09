@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Прибытие к проходу оценивается по земле, с авторским радиусом.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	return SUCCESS if NpcDecisionService.at_destination(_actor, NpcPopulationQueries.position_for(_person.goal_id), NpcDecisionService.schedule_distance(_person)) else FAILURE
#endregion
