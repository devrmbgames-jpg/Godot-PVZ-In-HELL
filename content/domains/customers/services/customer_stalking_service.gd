extends RefCounted
## Explicit rear-service choice, cancellation, real arrival and visibility-gated disclosure.
class_name CustomerStalkingService


#region Bounded role opportunity
static func begin(body: E_DistrictNpc) -> bool:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var player: Entity = CustomerStalkingQueries.target_for(body)
	if agent.stalking_sequence > 0:
		return CustomerStalkingQueries.active(body, player)
	player = ECS.world.query.with_all([C_PlayerInputController]).enabled().execute_one()
	if GameTimeQueries.current().paused or not CustomerStalkingQueries.available(body, player):
		return false
	var visit: CustomerVisit = CustomerFlowQueries.visit_for(body)
	if (
		agent.phase != C_CustomerAgent.Phase.APPROACHING
		or visit.stalking_visit_count >= visit.visit_count
	):
		return false
	# Entering this reserved service window is the source, even when watched or cooling down.
	# Eligibility expiry alone must not manufacture a later opportunity during the same visit.
	var eligible: bool = CustomerStalkingQueries.can_begin(body, player)
	visit.stalking_visit_count = visit.visit_count
	if not eligible:
		return false
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	var choice: NpcStalkingChoice = NpcStalkingService.choose(
		person,
		state.rule,
		state.rule.service_seconds,
	)
	if choice == null:
		return false
	if not choice.selected:
		return false
	var destination: Vector3 = NpcStalkingSolver.destination(
		body,
		person,
		player,
		state.rule,
		choice.candidate_offset,
	)
	if not destination.is_finite():
		return false
	agent.stalking_sequence = choice.sequence
	agent.stalking_deadline_tick = choice.deadline_tick
	agent.stalking_extra_ticks = choice.success_extra_ticks
	agent.stalking_destination = destination
	var relation: R_CustomerStalkingTarget = R_CustomerStalkingTarget.new()
	relation.visit_id = agent.visit_id
	relation.sequence = choice.sequence
	var link: Relationship = Relationship.new(relation, player)
	var world: World = ECS.world
	body.add_relationship(link)
	# Publication observers may retire/reset/rebind either participant synchronously.
	var committed: bool = (
		ECS.world == world and EntityAvailability.contains(body, world)
		and EntityAvailability.contains(player, world)
		and body.get_component(C_CustomerAgent) == agent
		and body.get_component(C_NpcStalking) == state
		and CustomerFlowQueries.visit_for(body) == visit
		and NpcPopulationQueries.person_for(person.npc_id) == person
		and agent.stalking_sequence == choice.sequence and body.relationships.has(link)
	)
	if not committed and is_instance_valid(body) and ECS.world == world:
		if body.relationships.has(link):
			body.remove_relationship(link)
	return committed
#endregion


#region Ended approach and actual contact
## Commits the same service arrival at the physically reached rear point, without a greeting.
static func arrive(body: E_DistrictNpc) -> bool:
	var player: Entity = CustomerStalkingQueries.target_for(body)
	if not CustomerStalkingQueries.active(body, player):
		return false
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	if (
		body.global_position.distance_to(agent.stalking_destination) > state.rule.arrival_tolerance
		or body.global_position.distance_to((player as Node as Node3D).global_position)
		>= NpcStalkingRules.SUCCESS_DISTANCE
		or NpcStalkingSolver.observed(body, player, body.global_position, state.rule)
	):
		return false
	return _commit_arrival(body, agent, state)


static func _commit_arrival(
	body: E_DistrictNpc,
	agent: C_CustomerAgent,
	state: C_NpcStalking,
) -> bool:
	var sequence: int = agent.stalking_sequence
	var world: World = ECS.world
	agent.rear_contact_pending = true
	agent.service_contact_position = body.global_position
	NpcStalkingService.release_service_motion(body, state.service_approach_task_id)
	if (
		ECS.world != world or not EntityAvailability.contains(body, world)
		or body.get_component(C_CustomerAgent) != agent
		or body.get_component(C_NpcStalking) != state or agent.stalking_sequence != sequence
	):
		return false
	NpcServiceRole.arrive(body, true)
	return (
		ECS.world == world and EntityAvailability.contains(body, world)
		and body.get_component(C_CustomerAgent) == agent and agent.stalking_sequence == sequence
		and agent.phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	)


## Commits a real close observation; distant detection merely aborts an unfinished detour.
static func notice(body: E_DistrictNpc, player: Entity) -> void:
	if not CustomerStalkingQueries.active(body, player):
		return
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	if not NpcStalkingSolver.observed(body, player, body.global_position, state.rule):
		return
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var distance: float = body.global_position.distance_to(
		(player as Node as Node3D).global_position
	)
	if NpcStalkingRules.close_success(true, true, distance):
		# Physics may reach the contact before the next cadence-controlled BT arrival leaf.
		if (
			agent.phase == C_CustomerAgent.Phase.APPROACHING
			and (
				body.global_position.distance_to(agent.stalking_destination)
				<= state.rule.arrival_tolerance
			)
		):
			if not _commit_arrival(body, agent, state):
				return
			if not EntityAvailability.contains(player, ECS.world):
				return
		NpcStalkingService.remember_notice(
			body,
			player,
			agent.stalking_sequence,
			agent.stalking_extra_ticks,
		)
	CustomerStalkingBindings.release(body)
	if (
		EntityAvailability.contains(body, ECS.world)
		and body.get_component(C_CustomerAgent) == agent
	):
		if EntityAvailability.contains(player, ECS.world):
			disclose_contact(body, player)
		NpcDecisionService.request_wake(body, &"rear_service_observed", true)


## A replacement camera owner may see the existing service contact without inheriting its success.
static func disclose_contact(body: E_DistrictNpc, player: Entity) -> void:
	var agent: C_CustomerAgent = body.get_component(C_CustomerAgent) as C_CustomerAgent
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	if (
		not agent.rear_contact_pending or GameTimeQueries.current().paused
		or agent.phase != C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
		or not EntityAvailability.contains(player, ECS.world) or player.has_component(C_Death)
		or not NpcStalkingSolver.observed(body, player, body.global_position, state.rule)
	):
		return
	agent.rear_contact_pending = false
	CustomerGreetingService.announce_order(body, CustomerFlowQueries.visit_for(body))
#endregion
