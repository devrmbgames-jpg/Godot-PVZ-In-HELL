extends RefCounted
## Read-only native feeding observations over perceived targets, service and conversation bindings.
class_name NpcFeedingTargetQueries


#region Native decision observations
## Only a visible target exposes its current floor state to the native decision branch.
static func target_at_floor(actor: E_DistrictNpc) -> bool:
	var rule: DEF_NpcFeeding = NpcFeedingQueries.rule_for(actor)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	var target: Entity = CombatQueries.target_for(actor)
	return (
		rule != null and awareness.target_visible and GrabQueries.holder_available(target)
		and not NpcFeedingQueries.can_attack(actor, target)
	)


## A visible living wounded player can motivate feeding outside active service/conversation.
static func wounded_player_for(actor: E_DistrictNpc) -> Entity:
	var rule: DEF_NpcFeeding = NpcFeedingQueries.rule_for(actor)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if (
		rule == null or not rule.valid_configuration() or not awareness.player_visible
		or awareness.fleeing or actor.has_active_role() or NpcGazeQueries.frozen(actor)
		or NpcDarknessQueries.combat_suppressed(actor) or NpcBloodQueries.calmed(actor)
		or CombatQueries.target_for(actor) != null or NpcDialogueService.participant(actor) != null
	):
		return null
	var player: Entity = ECS.world.query.with_all([C_PlayerInputController]).execute_one()
	if not GrabQueries.holder_available(player) or not NpcFeedingQueries.can_attack(actor, player):
		return null
	var health: C_Health = player.get_component(C_Health) as C_Health
	return player if health.current <= health.value * rule.wounded_health_fraction else null
#endregion
