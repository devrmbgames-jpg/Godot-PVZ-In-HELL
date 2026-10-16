extends RefCounted
## Read-only gates for the rear strategy inside an already reserved Customer service role.
class_name CustomerStalkingQueries


#region Role and live target
static func binding(body: Entity) -> Relationship:
	for link: Relationship in body.relationships:
		if link.relation is R_CustomerStalkingTarget:
			return link
	return null


## Resolves the optional captured player at the single live-binding lifetime boundary.
static func target_for(body: Entity) -> Entity:
	var link: Relationship = binding(body)
	return (
		link.target as Entity
		if link != null and EntityAvailability.contains(link.target, ECS.world)
		else null
	)


## Arrival keeps its fixed service contact; only an approaching detour needs the counter-zone gate.
static func available(body: E_DistrictNpc, player: Entity) -> bool:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	var visit: CustomerVisit = CustomerFlowQueries.visit_for(body)
	if (
		agent == null or state.rule == null or not state.rule.valid_configuration()
		or visit == null or visit.finished or HomeMeetingQueries.meeting_for(body) != null
		or person.placement != NpcRecord.Placement.STREET or person.death_day != 0
		or body.has_component(C_Death) or awareness.fleeing or awareness.hazard_distress
		or CombatQueries.target_for(body) != null or NpcDialogueService.participant(body) != null
		or not EntityAvailability.contains(player, ECS.world)
		or player.has_component(C_Death) or not player.has_component(C_PlayerInputController)
		or NpcGazeAversionSolver.camera_for(player) == null
		or DayPhaseQueries.current().phase != C_DayCycle.Phase.DAY
	):
		return false
	var approaching: bool = agent.phase == C_CustomerAgent.Phase.APPROACHING
	if (
		not approaching
		and not (
			agent.rear_contact_pending and agent.phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
		)
	):
		return false
	var station: E_DeliveryCounter = CustomerFlowQueries.counter()
	if not EntityAvailability.contains(station, ECS.world):
		return false
	var reserved: bool = false
	for link: Relationship in body.relationships:
		if (
			link.relation is R_NpcServiceAt and link.target == station
			and (link.relation as R_NpcServiceAt).visit_id == agent.visit_id
		):
			reserved = true
	if not reserved:
		return false
	if not approaching:
		return true
	var position: Vector3 = (player as Node as Node3D).global_position
	return (
		awareness.player_visible and agent.elapsed < visit.definition.approach_timeout
		and position.distance_to(station.waiting_position()) <= state.rule.service_player_range
		and body.global_position.distance_to(position) <= state.rule.approach_range
	)


static func can_begin(body: E_DistrictNpc, player: Entity) -> bool:
	if GameTimeQueries.current().paused or not available(body, player):
		return false
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowQueries.visit_for(body)
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	return (
		agent.phase == C_CustomerAgent.Phase.APPROACHING and agent.stalking_sequence == 0
		and visit.stalking_visit_count < visit.visit_count
		and NpcStalkingRules.opportunity_due(person, GameTimeQueries.current().elapsed_ticks)
		and not NpcStalkingSolver.observed(body, player, body.global_position, state.rule)
	)


static func active(body: E_DistrictNpc, player: Entity) -> bool:
	if GameTimeQueries.current().paused or not available(body, player):
		return false
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var link: Relationship = binding(body)
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	return (
		agent.stalking_sequence > 0 and agent.stalking_sequence == person.stalking_sequence
		and link != null and link.target == player
		and (link.relation as R_CustomerStalkingTarget).sequence == agent.stalking_sequence
		and (link.relation as R_CustomerStalkingTarget).visit_id == agent.visit_id
		and (
			agent.rear_contact_pending
			or GameTimeQueries.current().elapsed_ticks < agent.stalking_deadline_tick
		)
	)
#endregion
