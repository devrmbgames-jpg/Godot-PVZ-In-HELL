@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Binds one perceived target through the existing social/combat operation without an offense.


#region Explicit hunt start
func _tick(_delta: float) -> Status:
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if (
		not _awareness.player_visible or not GrabQueries.holder_available(player)
		or player.has_component(C_Death)
	):
		return FAILURE
	if not _claim("Охота в темноте"):
		return FAILURE
	var world: World = ECS.world
	var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.participation_generation
	_awareness.fleeing = false
	NpcSocialService.apply_reaction(_actor, player, NpcMemory.Reaction.ATTACK)
	# Published reactions can retire the receiver or replace its brain synchronously.
	if (
		not EntityAvailability.contains(_actor, world)
		or ECS.world != world or _actor.get_component(C_NpcDecision) != decision
		or decision.participation_generation != generation
		or _actor.get_component(C_NpcAwareness) != _awareness
	):
		# Consume the obsolete branch so its selector cannot enter siblings on a retired agent.
		return SUCCESS
	if CombatQueries.target_for(_actor) != player:
		return FAILURE
	_awareness.target_visible = true
	return SUCCESS
#endregion
