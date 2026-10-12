@tool
extends "res://content/domains/npc/ai/tasks/bt_npc_action.gd"
## Starts one perceived feeding conflict through the social/combat owner, without an offense.


func _tick(_delta: float) -> Status:
	var player: Entity = NpcFeedingTargetQueries.wounded_player_for(_actor)
	if player == null or not _claim("Питание видимым раненым игроком"):
		return FAILURE
	var world: World = ECS.world
	var decision: C_NpcDecision = _actor.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.participation_generation
	NpcSocialService.apply_reaction(_actor, player, NpcMemory.Reaction.ATTACK)
	# Reactions may synchronously retire the actor or replace the native participation contract.
	if (
		not EntityAvailability.contains(_actor, world)
		or ECS.world != world or _actor.get_component(C_NpcDecision) != decision
		or decision.participation_generation != generation
		or _actor.get_component(C_NpcAwareness) != _awareness
	):
		return SUCCESS
	if CombatQueries.target_for(_actor) != player:
		return FAILURE
	_awareness.target_visible = true
	return SUCCESS
