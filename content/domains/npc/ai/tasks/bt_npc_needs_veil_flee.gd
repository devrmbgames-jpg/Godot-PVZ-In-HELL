@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Starts cloud flight only for a confirmed visible threat, or continues a committed flight.


#region Confirmed danger
func _tick(_delta: float) -> Status:
	var rule: DEF_NpcVeil = NpcVeilQueries.rule_for(_person)
	if rule == null:
		return FAILURE
	if _awareness.fleeing:
		return SUCCESS
	var health: C_Health = _actor.get_component(C_Health) as C_Health
	var target: Entity = CombatQueries.target_for(_actor)
	return (
		SUCCESS
		if (
			target != null and health.current < health.value * rule.escape_health_fraction
			and NpcPerceptionService.can_see(_actor, target, _person)
		)
		else FAILURE
	)
#endregion
