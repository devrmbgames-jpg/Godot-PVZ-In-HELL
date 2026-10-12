extends System
## Owns frame-rate camera exposure and urgent decision invalidation; Observer owns recognition.
class_name S_NpcStalkingWitness


#region Scheduled camera exposure
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase], Runs.Before: [S_NpcCadence, S_NpcIntent] }


func query() -> QueryBuilder:
	return q.with_all([C_NpcStalking, C_NpcDecision, C_NpcIdentity]).with_none([C_Death]).enabled()


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	var delta: float = GameTimeRules.seconds(GameTimeQueries.current().step_ticks)
	for entity: Entity in entities:
		var state: C_NpcStalking = entity.get_component(C_NpcStalking) as C_NpcStalking
		if state.rule != null:
			var generation: int = (
				entity.get_component(C_NpcDecision) as C_NpcDecision
			).lifecycle_generation
			cmd.add_custom(_sample.bind(weakref(entity), state, generation, maxf(0.0, delta)))


func _sample(reference: WeakRef, state: C_NpcStalking, generation: int, delta: float) -> void:
	var body: E_DistrictNpc = reference.get_ref() as E_DistrictNpc
	if (
		not EntityAvailability.contains(body, _world) or body.has_component(C_Death)
		or body.get_component(C_NpcStalking) != state or state.rule == null
		or (body.get_component(C_NpcDecision) as C_NpcDecision).lifecycle_generation != generation
	):
		return
	var player: Entity = _world.query.with_all([C_PlayerInputController]).enabled().execute_one()
	var person: NpcRecord = NpcPopulationQueries.person_for(NpcSocialService.identity_for(body))
	var player_incarnation: int = (
		player.get_instance_id() if EntityAvailability.contains(player, _world) else 0
	)
	if state.sampled_player_instance_id != player_incarnation:
		state.sampled_player_instance_id = player_incarnation
		state.exposure_seconds = 0.0
	var observed: bool = (
		EntityAvailability.contains(player, _world) and not player.has_component(C_Death)
		and not NpcStalkingRules.noticed(person, NpcSocialService.identity_for(player))
		and NpcStalkingSolver.observed(body, player, body.global_position, state.rule)
	)
	if observed != state.observed:
		state.observed = observed
		NpcDecisionService.request_wake(body, &"stalking_visibility_changed", true)
	if not observed:
		state.exposure_seconds = 0.0
		return
	var previous: float = state.exposure_seconds
	state.exposure_seconds = minf(state.rule.notice_seconds, previous + delta)
	if previous < state.rule.notice_seconds and state.exposure_seconds >= state.rule.notice_seconds:
		_world.emit_event(
			NpcStalkingNoticeRequest.EVENT,
			body,
			NpcStalkingNoticeRequest.new(body, player, state),
		)
#endregion
