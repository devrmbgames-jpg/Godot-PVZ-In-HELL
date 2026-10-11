@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Light ends a typed predator's current combat before emergency/attack consumers.


#region Sampled light guard
func _tick(_delta: float) -> Status:
	return (
		SUCCESS
		if NpcDarknessQueries.combat_suppressed(_actor) \
				and CombatQueries.target_for(_actor) != null
		else FAILURE
	)
#endregion
