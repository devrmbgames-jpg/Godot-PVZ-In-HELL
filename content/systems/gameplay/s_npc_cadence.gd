extends System
## Owns native NPC interval accumulation and captures one shared due interval for all AI stages.
class_name S_NpcCadence

#region Scheduling
## Eligibility follows district/customer commits and precedes all sampled AI work.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_District, S_CustomerFlow, S_CustomerArrivals, S_DayPhase], Runs.Before: [S_NpcFootsteps, S_NpcPerception, S_NpcTraits, S_NpcDecision]}


## Selects the ECS-owned population and authoritative calendar.
func query() -> QueryBuilder:
	return q.with_all([C_District, C_DayCycle])


## Queues interval selection at the declared structural boundary.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for session: Entity in entities:
		var captured_district: C_District = session.get_component(C_District) as C_District
		var captured_cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		cmd.add_custom(_select_due.bind(weakref(session), delta, captured_district, captured_cycle))
#endregion

#region Due selection
func _select_due(session_reference: WeakRef, delta: float, captured_district: C_District, captured_cycle: C_DayCycle) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if not EntityAvailability.contains(session, _world) \
			or session.get_component(C_District) != captured_district \
			or session.get_component(C_DayCycle) != captured_cycle:
		return

	var district: C_District = session.get_component(C_District) as C_District
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	for person: NpcRecord in district.people:
		var actor: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
		if actor == null:
			continue
		var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
		if decision != null:
			decision.scheduled_delta = 0.0
		if cycle.phase == C_DayCycle.Phase.NIGHT or person.death_day != 0 \
				or person.placement != NpcRecord.Placement.STREET or not actor.enabled:
			continue

		# Materialization normally installs these; explicit lifecycle repair preserves the adapter contract.
		if decision == null or not actor.has_component(C_NpcAwareness) or actor.get_node_or_null("Brain") == null:
			NpcBrainService.install(actor)
			decision = actor.get_component(C_NpcDecision) as C_NpcDecision
		decision.update_elapsed += maxf(0.0, delta)
		if decision.update_elapsed >= district.definition.decision_interval:
			decision.scheduled_delta = decision.update_elapsed
			decision.scheduled_day = cycle.day_index
			decision.scheduled_phase = int(cycle.phase)
#endregion
