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
	var choice: NpcStalkingChoice = choose(
		person, state.rule, state.rule.episode_seconds, state.rule.delay_seconds,
	)
	if choice == null:
		return false
	state.opportunity_available = false
	state.opportunity_expires_tick = 0
	if not choice.selected:
		return false
	var sequence: int = choice.sequence
	state.episode_sequence = sequence
	state.ready_tick = choice.ready_tick
	state.deadline_tick = choice.deadline_tick
	state.success_extra_ticks = choice.success_extra_ticks
	state.candidate_offset = choice.candidate_offset
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


## Commits the shared personal choice for a free opportunity or one explicitly authorized role.
## The caller owns suitability/once-per-context gates; this operation alone writes RNG history.
static func choose(
	person: NpcRecord, rule: DEF_NpcStalking, active_seconds: float, delay_seconds: float = 0.0,
) -> NpcStalkingChoice:
	var now: int = GameTimeQueries.current().elapsed_ticks
	if (
		GameTimeQueries.current().paused or not rule.valid_configuration()
		or not is_finite(active_seconds) or active_seconds <= 0.0 or active_seconds > 15.0
		or not is_finite(delay_seconds) or delay_seconds < 0.0 or delay_seconds > 5.0
		or not NpcStalkingRules.opportunity_due(person, now)
	):
		return null
	var maximum_duration: int = GameTimeRules.duration_ticks(
		delay_seconds + active_seconds + rule.retry_seconds,
	)
	if now > NpcStalkingRules.MAX_COUNTER - maximum_duration:
		return null
	var sequence: int = person.stalking_sequence + 1
	var random: RandomNumberGenerator = GameTimeQueries.decision(
		String(person.npc_id),
		DayPhaseQueries.current().day_index,
		"npc/stalking",
		sequence,
	)
	var selected: bool = random.randf() < rule.opportunity_probability
	var delay: int = GameTimeRules.duration_ticks(random.randf() * delay_seconds)
	var extra: int = GameTimeRules.duration_ticks(random.randf() * rule.success_extra_seconds)
	var sector: int = random.randi_range(0, NpcStalkingSolver.BEHIND_ANGLES.size() - 1)
	person.stalking_sequence = sequence
	person.stalking_decision_tick = now
	person.stalking_next_eligible_tick = now + (
		maximum_duration if selected else GameTimeRules.duration_ticks(rule.retry_seconds)
	)
	var choice: NpcStalkingChoice = NpcStalkingChoice.new()
	choice.sequence = sequence
	choice.selected = selected
	choice.ready_tick = now + delay
	choice.deadline_tick = choice.ready_tick + GameTimeRules.duration_ticks(active_seconds)
	choice.success_extra_ticks = extra
	choice.candidate_offset = sector
	return choice
#endregion


#region Customer strategy motion boundary
## Captures a Customer leaf's speed request only after native arbitration assigned its move token.
static func claim_service_motion(body: Entity, token: int) -> void:
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	if token != 0 and decision.active_task_id == token \
			and decision.intent_owner == C_NpcDecision.Owner.SERVICE:
		(body.get_component(C_NpcStalking) as C_NpcStalking).service_approach_task_id = token


## Releases only the captured Customer motion; synchronous callbacks cannot cancel a new branch.
static func release_service_motion(body: Entity, token: int) -> void:
	var state: C_NpcStalking = body.get_component(C_NpcStalking) as C_NpcStalking
	if token == 0 or state.service_approach_task_id != token:
		return
	state.service_approach_task_id = 0
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	if decision.active_task_id != token:
		return
	var world: World = ECS.world
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
		# A retired rear route cannot supply the ordinary counter's arrival result.
		(body.get_component(C_NpcIntent) as C_NpcIntent).arrived = false
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
	if NpcStalkingRules.close_success(true, true, distance):
		if not remember_notice(body, player, sequence, state.success_extra_ticks):
			cancel(body)
			return
	NpcDecisionService.request_wake(body, &"stalking_episode_closed", true)
	cancel(body)


## Commits the shared neutral personal success after the caller proves actual close observation.
## The sequence must still identify this person's latest committed free or service opportunity.
static func remember_notice(
	body: E_DistrictNpc, player: Entity, sequence: int, extra_ticks: int,
) -> bool:
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	var now: int = GameTimeQueries.current().elapsed_ticks
	var deadline: int = NpcStalkingRules.success_deadline(now, extra_ticks)
	if sequence <= 0 or sequence != person.stalking_sequence or deadline < 0:
		return false
	person.stalking_notice_tick = now
	person.stalking_next_eligible_tick = maxi(person.stalking_next_eligible_tick, deadline)
	NpcSocialService.remember(
		person, player, body, NpcMemory.Kind.STALKING_NOTICED,
		NpcStalkingRules.episode_incident(person, NpcSocialService.identity_for(player), sequence),
		NpcMemory.Reaction.TALK,
	)
	return true
#endregion
