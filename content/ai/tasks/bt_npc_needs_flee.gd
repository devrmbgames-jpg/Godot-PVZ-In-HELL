@tool
extends "res://content/ai/tasks/bt_npc_condition.gd"
## Бегство требует подтверждённой реакции либо опасного недостатка здоровья.

#region Проверка состояния
func _tick(_delta: float) -> Status:
	var health: C_Health = _actor.get_component(C_Health) as C_Health
	return SUCCESS if _awareness.fleeing or (CombatService.target_for(_actor) != null and health.current < health.value * _person.profile.pursuit_health_reserve) else FAILURE
#endregion
