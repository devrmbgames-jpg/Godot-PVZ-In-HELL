extends System
## Owns frame-rate observation state and urgent invalidation before the existing AI cadence.
class_name S_NpcGazeFreeze


#region Scheduling and sampling
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase], Runs.Before: [S_NpcCadence, S_NpcCombat, S_NpcIntent] }


func query() -> QueryBuilder:
	return q.with_all([C_NpcGazeFreeze, C_NpcDecision]).with_none([C_Death]).enabled()


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for entity: Entity in entities:
		var constraint: C_NpcGazeFreeze = entity.get_component(C_NpcGazeFreeze) as C_NpcGazeFreeze
		if constraint.rule != null:
			cmd.add_custom(_sample.bind(weakref(entity), constraint))


func _sample(actor_reference: WeakRef, captured: C_NpcGazeFreeze) -> void:
	var actor: E_DistrictNpc = actor_reference.get_ref() as E_DistrictNpc
	if (
		not EntityAvailability.contains(actor, _world) or actor.has_component(C_Death)
		or actor.get_component(C_NpcGazeFreeze) != captured or captured.rule == null
	):
		return
	var player: Entity = _world.query.with_all([C_PlayerInputController]).enabled().execute_one()
	var observed: bool = NpcCameraVisibility.observed(actor, player, captured.rule)
	if captured.observed == observed:
		return
	# Both edges retire the response sampled under the previous observation constraint.
	actor.clear_physical_motion()
	captured.observed = observed
	if observed:
		# Cancel the current execution, retaining R_CombatTarget for the next unobserved decision.
		NpcAttackExecutionService.cancel(actor)
	actor.sync_gaze_constraint()
	NpcDecisionService.request_wake(actor, &"camera_observation_changed", true)
#endregion
