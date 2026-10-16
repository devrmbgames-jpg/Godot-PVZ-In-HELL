extends RefCounted
## Explicit opportunity/interruption/recognition commits; its System owns recurring sensing.
class_name NpcStalkingService


#region Opportunity transaction
## Captures one decision and its eligibility deadline before publishing the live target binding.
## False includes a committed skipped opportunity; repeated BT ticks cannot reroll it.
static func begin(body: E_DistrictNpc, player: Entity) -> bool:
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	if not NpcStalkingQueries.eligible(body, person, player):
		return false
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	if state.episode_sequence > 0:
		return true
	if NpcStalkingSolver.observed(body, player, body.global_position, state.rule):
		return false
	var now: int = GameTimeQueries.current().elapsed_ticks
	var maximum_duration: int = GameTimeRules.duration_ticks(
		state.rule.delay_seconds + state.rule.episode_seconds + state.rule.retry_seconds,
	)
	if now > NpcStalkingRules.MAX_COUNTER - maximum_duration:
		return false
	var sequence: int = person.stalking_sequence + 1
	var random: RandomNumberGenerator = GameTimeQueries.decision(
		String(person.npc_id),
		DayPhaseQueries.current().day_index,
		"npc/stalking",
		sequence,
	)
	var selected: bool = random.randf() < state.rule.opportunity_probability
	var delay: int = GameTimeRules.duration_ticks(random.randf() * state.rule.delay_seconds)
	var extra: int = GameTimeRules.duration_ticks(random.randf() * state.rule.success_extra_seconds)
	var sector: int = random.randi_range(0, NpcStalkingSolver.BEHIND_ANGLES.size() - 1)
	state.opportunity_available = false
	state.opportunity_expires_tick = 0
	person.stalking_sequence = sequence
	person.stalking_decision_tick = now
	person.stalking_next_eligible_tick = now + (
		maximum_duration if selected else GameTimeRules.duration_ticks(state.rule.retry_seconds)
	)
	if not selected:
		return false

	state.episode_sequence = sequence
	state.ready_tick = now + delay
	state.deadline_tick = state.ready_tick + GameTimeRules.duration_ticks(
		state.rule.episode_seconds
	)
	state.success_extra_ticks = extra
	state.candidate_offset = sector
	state.replans_left = state.rule.max_replans
	state.sampled_position = (player as Node as Node3D).global_position
	state.origin = body.global_position
	var relation: R_NpcStalkingTarget = R_NpcStalkingTarget.new()
	relation.sequence = sequence
	var link: Relationship = Relationship.new(relation, player)
	var world: World = ECS.world
	body.add_relationship(link)
	# Native relationship observers can reset/retire either participant during publication.
	var committed: bool = (
		ECS.world == world and EntityAvailability.contains(body, world)
		and EntityAvailability.contains(player, world)
		and body.get_component(C_NpcStalking) == state
		and NpcPopulationQueries.person_for(person.npc_id) == person
		and state.episode_sequence == sequence and body.relationships.has(link)
	)
	if not committed and is_instance_valid(body) and ECS.world == world:
		if body.relationships.has(link):
			body.remove_relationship(link)
	return committed
#endregion


#region Episode closure
## Clears only this episode and its motion token; captured durable deadlines never reset here.
static func cancel(body: E_DistrictNpc) -> void:
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	var token: int = state.approach_task_id
	var links: Array[Relationship] = []
	for link: Relationship in body.relationships:
		if link.relation is R_NpcStalkingTarget:
			links.append(link)
	state.reset_episode()
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var world: World = ECS.world
	if token != 0 and decision.active_task_id == token:
		NpcIntentService.stop(body)
		if (
			not is_instance_valid(body) or not is_instance_valid(world) or ECS.world != world
			or not world.entity_to_archetype.has(body)
			or body.get_component(C_NpcStalking) != state
			or body.get_component(C_NpcDecision) != decision
		):
			return
		if decision.active_task_id == token:
			decision.active_task_id = 0
	for link: Relationship in links:
		if body.relationships.has(link):
			body.remove_relationship(link)
		if (
			not is_instance_valid(body) or not is_instance_valid(world) or ECS.world != world
			or not world.entity_to_archetype.has(body)
			or body.get_component(C_NpcStalking) != state or state.episode_sequence != 0
		):
			return


## Commits a real close observation once; distant detection ends the episode without success memory.
static func notice(body: E_DistrictNpc, player: Entity) -> void:
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	if (
		state.episode_sequence == 0 or GameTimeQueries.current().paused
		or not NpcStalkingQueries.eligible(body, person, player)
		or not NpcStalkingSolver.observed(body, player, body.global_position, state.rule)
	):
		return
	var sequence: int = state.episode_sequence
	var distance: float = body.global_position.distance_to(
		(player as Node as Node3D).global_position
	)
	var now: int = GameTimeQueries.current().elapsed_ticks
	if NpcStalkingRules.close_success(true, true, distance):
		var deadline: int = NpcStalkingRules.success_deadline(now, state.success_extra_ticks)
		if deadline < 0:
			cancel(body)
			return
		person.stalking_notice_tick = now
		person.stalking_next_eligible_tick = maxi(person.stalking_next_eligible_tick, deadline)
		NpcSocialService.remember(
			person,
			player,
			body,
			NpcMemory.Kind.STALKING_NOTICED,
			NpcStalkingRules.episode_incident(
				person,
				NpcSocialService.identity_for(player),
				sequence,
			),
			NpcMemory.Reaction.TALK,
		)
	NpcDecisionService.request_wake(body, &"stalking_episode_closed", true)
	cancel(body)
#endregion
