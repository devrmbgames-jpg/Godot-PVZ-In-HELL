@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Concealment follows remembered flight after losing sight, never reads a hidden target position.


#region Native alternative condition
func _tick(_delta: float) -> Status:
	var rule: DEF_NpcVeil = NpcVeilQueries.rule_for(_person)
	return (
		SUCCESS
		if (
			rule != null and rule.allow_invisible_escape and _awareness.fleeing
			and _awareness.has_last_seen and not _awareness.player_visible
			and CombatQueries.target_for(_actor) == null
		)
		else FAILURE
	)
#endregion
