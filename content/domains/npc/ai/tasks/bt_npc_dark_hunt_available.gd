@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_condition.gd"
## Only a currently perceived living player in authored darkness can start a new hunt.


#region Sampled hunt guard
func _tick(_delta: float) -> Status:
	var rule: DEF_NpcDarkPredator = (
		_person.rule_for(DEF_NpcTrait.Kind.DARK_PREDATOR) as DEF_NpcDarkPredator
	)
	if (
		not NpcTraitRules.player_in_hunting_darkness(_awareness, rule)
		or NpcBloodQueries.calmed(_actor) or CombatQueries.target_for(_actor) != null
	):
		return FAILURE
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	return (
		SUCCESS
		if GrabQueries.holder_available(player) \
				and not player.has_component(C_Death)
		else FAILURE
	)
#endregion
