@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Guards the authored ranged preference using only current target perception and execution state.


#region Observed combat capability
func _tick(_delta: float) -> Status:
	var target: Entity = CombatQueries.target_for(_actor)
	var state: C_NpcCombat = _actor.get_component(C_NpcCombat) as C_NpcCombat
	return (
		SUCCESS
		if (
			_person.profile.combat_preference == DEF_NpcArchetype.CombatPreference.RANGED
			and _awareness.target_visible and NpcAttackService.pair_available(_actor, target)
			and state.phase == C_NpcCombat.Phase.READY
			and NpcRangedPositionSolver.variant(state) >= 0
		)
		else FAILURE
	)
#endregion
