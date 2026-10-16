extends System
## Samples real camera visibility and closes active episodes; elapsed time belongs to GameClock.
class_name S_NpcStalkingWitness


#region Scheduled visibility sampling
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase], Runs.Before: [S_NpcCadence, S_NpcIntent] }


func query() -> QueryBuilder:
	return q.with_all([C_NpcStalking, C_NpcDecision, C_NpcIdentity]).with_none([C_Death]).enabled()


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	var advancing: bool = GameTimeQueries.current().step_ticks > 0
	for entity: Entity in entities:
		var state: C_NpcStalking = entity.get_component(C_NpcStalking) as C_NpcStalking
		if state.rule != null:
			var generation: int = (
				entity.get_component(C_NpcDecision) as C_NpcDecision
			).lifecycle_generation
			cmd.add_custom(_sample.bind(weakref(entity), state, generation, advancing))


func _sample(reference: WeakRef, state: C_NpcStalking, generation: int, advancing: bool) -> void:
	var body: E_DistrictNpc = reference.get_ref() as E_DistrictNpc
	if (
		not EntityAvailability.contains(body, _world) or body.has_component(C_Death)
		or body.get_component(C_NpcStalking) != state or state.rule == null
		or (body.get_component(C_NpcDecision) as C_NpcDecision).lifecycle_generation != generation
	):
		return
	var player: Entity = _world.query.with_all([C_PlayerInputController]).enabled().execute_one()
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	if state.episode_sequence > 0 and (
		not NpcStalkingQueries.participants_available(body, person, player)
		or GameTimeQueries.current().paused
		or NpcStalkingQueries.target_for(body) != player
		or GameTimeQueries.current().elapsed_ticks >= state.deadline_tick
	):
		NpcStalkingService.cancel(body)
		if (
			not EntityAvailability.contains(body, _world)
			or body.get_component(C_NpcStalking) != state
		):
			return
		NpcDecisionService.request_wake(body, &"stalking_episode_interrupted", true)
	var player_incarnation: int = (
		player.get_instance_id() if EntityAvailability.contains(player, _world) else 0
	)
	if state.sampled_player_instance_id != player_incarnation:
		state.context_initialized = false
	state.sampled_player_instance_id = player_incarnation
	var observed: bool = (
		player_incarnation != 0 and not player.has_component(C_Death)
		and NpcStalkingSolver.observed(body, player, body.global_position, state.rule)
	)
	if observed != state.observed:
		state.observed = observed
		NpcDecisionService.request_wake(body, &"stalking_visibility_changed", true)
	var now: int = GameTimeQueries.current().elapsed_ticks
	var reading: bool = player_incarnation != 0 and TerminalQueries.reading(player)
	var context: bool = (
		not observed and not GameTimeQueries.current().paused
		and NpcStalkingQueries.participants_available(body, person, player)
	)
	var opportunity: bool = context and (
		not state.context_available or (reading and not state.terminal_reading)
	)
	if not state.context_initialized:
		opportunity = context and person.stalking_sequence == 0
	state.context_initialized = true
	state.context_available = context
	state.terminal_reading = reading
	if (
		not context or not NpcStalkingRules.opportunity_due(person, now)
		or now >= state.opportunity_expires_tick
	):
		state.opportunity_available = false
	if opportunity and NpcStalkingRules.opportunity_due(person, now):
		var duration: int = GameTimeRules.duration_ticks(state.rule.episode_seconds)
		state.opportunity_expires_tick = now + mini(duration, NpcStalkingRules.MAX_COUNTER - now)
		state.opportunity_available = now < state.opportunity_expires_tick
		if state.opportunity_available:
			NpcDecisionService.request_wake(body, &"stalking_opportunity", true)
	if observed and advancing and state.episode_sequence > 0:
		_world.emit_event(
			NpcStalkingNoticeRequest.EVENT, body, NpcStalkingNoticeRequest.new(body, player, state),
		)
#endregion
