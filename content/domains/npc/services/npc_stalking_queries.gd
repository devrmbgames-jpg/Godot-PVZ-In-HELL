extends RefCounted
## Read-only stalking eligibility; service, conversation and combat retain their own authority.
class_name NpcStalkingQueries


#region Native decision eligibility
## Suppresses only the active hidden approach, without freezing combat, service or schedule.
static func holds_approach(actor: Entity) -> bool:
	var state: C_NpcStalking = actor.get_component(C_NpcStalking) as C_NpcStalking
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	return (
		state != null and state.observed and state.approach_task_id != 0
		and decision.active_task_id == state.approach_task_id
		and decision.intent_owner == C_NpcDecision.Owner.IDLE
	)


static func eligible(actor: E_DistrictNpc, person: NpcRecord, player: Entity) -> bool:
	var state: C_NpcStalking = actor.get_component(C_NpcStalking) as C_NpcStalking
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if (
		state.rule == null or not state.rule.valid_configuration()
		or person.placement != NpcRecord.Placement.STREET or person.death_day != 0
		or not person.phase_complete or actor.has_component(C_Death)
		or not awareness.player_visible or awareness.fleeing
		or CombatQueries.target_for(actor) != null or NpcDialogueService.participant(actor) != null
		or actor.has_active_role() or player == null or player.has_component(C_Death)
		or NpcStalkingRules.noticed(person, NpcSocialService.identity_for(player))
	):
		return false
	var spatial: Node3D = player as Node as Node3D
	if spatial == null or NpcGazeAversionSolver.camera_for(player) == null:
		return false
	var reach: float = state.rule.approach_range
	if TerminalQueries.reading(player):
		reach += state.rule.terminal_range_bonus
	return actor.global_position.distance_to(spatial.global_position) <= reach
#endregion
