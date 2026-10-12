@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Commits one witnessed-toy offense through social/combat ownership, then exposes normal combat.


#region Explicit toy offense
func _tick(_delta: float) -> Status:
	var incident: StringName = NpcPrideQueries.pending_toy_incident(_actor, _person)
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).enabled().execute_one()
	if incident == &"" or not GrabQueries.holder_available(player) or player.has_component(C_Death):
		return FAILURE
	if not _claim("Ты видел мою игрушку!"):
		return FAILURE
	var world: World = ECS.world
	var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.participation_generation
	NpcSocialService.escalate_toy(_actor, player, incident)
	# Published reactions can replace/retire this native runner synchronously.
	if (
		not EntityAvailability.contains(_actor, world)
		or ECS.world != world or _actor.get_component(C_NpcDecision) != decision
		or decision.participation_generation != generation
		or _actor.get_component(C_NpcAwareness) != _awareness
	):
		return SUCCESS
	_awareness.target_visible = CombatQueries.target_for(_actor) == player
	return SUCCESS
#endregion
