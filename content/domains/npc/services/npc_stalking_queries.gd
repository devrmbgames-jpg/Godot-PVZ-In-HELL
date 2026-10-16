extends RefCounted
## Read-only opportunity/episode gates; higher-priority roles retain their existing authority.
class_name NpcStalkingQueries


#region Episode binding and eligibility
## Returns the one captured live-target binding, including an endpoint awaiting lifecycle cleanup.
static func binding(actor: Entity) -> Relationship:
	for link: Relationship in actor.relationships:
		if link.relation is R_NpcStalkingTarget:
			return link
	return null


## Resolves the optional live target at this single lifetime boundary.
static func target_for(actor: Entity) -> Entity:
	var link: Relationship = binding(actor)
	return (
		link.target as Entity
		if link != null and EntityAvailability.contains(link.target, ECS.world)
		else null
	)


## Suppresses only the owned hidden motion until the observed episode is closed.
static func holds_approach(actor: Entity) -> bool:
	var state: C_NpcStalking = actor.get_component(C_NpcStalking) as C_NpcStalking
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	return (
		state != null and state.observed and state.episode_sequence > 0
		and state.approach_task_id != 0 and decision.active_task_id == state.approach_task_id
		and decision.intent_owner == C_NpcDecision.Owner.IDLE
	)


## High-priority interruptions and range are independent of old recognition history or cooldown.
static func participants_available(actor: E_DistrictNpc, person: NpcRecord, player: Entity) -> bool:
	var state: C_NpcStalking = actor.get_component(C_NpcStalking) as C_NpcStalking
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	if (
		state.rule == null or not state.rule.valid_configuration()
		or person.placement != NpcRecord.Placement.STREET or person.death_day != 0
		or not person.phase_complete or actor.has_component(C_Death) or not awareness.player_visible
		or awareness.fleeing or CombatQueries.target_for(actor) != null
		or NpcDialogueService.participant(actor) != null or actor.has_active_role()
		or not EntityAvailability.contains(player, ECS.world) or player.has_component(C_Death)
	):
		return false
	var spatial: Node3D = player as Node as Node3D
	if spatial == null or NpcGazeAversionSolver.camera_for(player) == null:
		return false
	var reach: float = state.rule.approach_range
	if TerminalQueries.reading(player):
		reach += state.rule.terminal_range_bonus
	if state.episode_sequence > 0 and actor.global_position.distance_to(state.origin) > reach:
		return false
	return actor.global_position.distance_to(spatial.global_position) <= reach


## A due clock allows one decision; a captured episode can continue until its deadline.
static func eligible(actor: E_DistrictNpc, person: NpcRecord, player: Entity) -> bool:
	if not participants_available(actor, person, player) or GameTimeQueries.current().paused:
		return false
	var state: C_NpcStalking = actor.get_component(C_NpcStalking) as C_NpcStalking
	var now: int = GameTimeQueries.current().elapsed_ticks
	if state.episode_sequence > 0:
		var link: Relationship = binding(actor)
		return (
			link != null and link.target == player
			and (link.relation as R_NpcStalkingTarget).sequence == state.episode_sequence
			and now < state.deadline_tick
		)
	return (
		NpcStalkingRules.opportunity_due(person, now) and not state.observed
		and state.opportunity_available and now < state.opportunity_expires_tick
		and state.sampled_player_instance_id == player.get_instance_id()
	)
#endregion
