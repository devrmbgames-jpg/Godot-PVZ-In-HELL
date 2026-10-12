@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Tests the observed firing-distance band without changing movement or attack state.


#region Observed firing position
func _tick(_delta: float) -> Status:
	var state: C_NpcCombat = _actor.get_component(C_NpcCombat) as C_NpcCombat
	var variant: int = NpcRangedPositionSolver.variant(state)
	return (
		SUCCESS
		if (
			variant >= 0
			and NpcRangedPositionSolver.positioned(
				_actor.global_position,
				_awareness.last_seen_position,
				state.ranged_attacks[variant],
			)
		)
		else FAILURE
	)
#endregion
