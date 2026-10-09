extends System
## Owns persisted AI cadence against the session timestamp and captures one shared native interval.
class_name S_NpcCadence

#region Scheduling
## Eligibility follows district/customer commits and precedes all sampled AI work.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_GameTime, S_District, S_DayPhase], Runs.Before: [S_NpcFootsteps, S_NpcPerception, S_NpcTraits, S_NpcDecision]}


## Selects the ECS-owned population and authoritative calendar.
func query() -> QueryBuilder:
	return q.with_all([C_District, C_DayCycle])


## Queues interval selection at the declared structural boundary.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for session: Entity in entities:
		var captured_district: C_District = session.get_component(C_District) as C_District
		var captured_cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		cmd.add_custom(_select_due.bind(weakref(session), captured_district, captured_cycle))
#endregion

#region Due selection
func _select_due(session_reference: WeakRef, captured_district: C_District, captured_cycle: C_DayCycle) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if not EntityAvailability.contains(session, _world) \
			or session.get_component(C_District) != captured_district \
			or session.get_component(C_DayCycle) != captured_cycle:
		return

	var district: C_District = session.get_component(C_District) as C_District
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	var clock: GameClock = cycle.clock
	if clock.paused:
		return
	var interval_ticks: int = GameTimeRules.duration_ticks(district.definition.decision_interval)
	assert(interval_ticks > 0, "NPC decision interval must be positive")
	for person: NpcRecord in district.people:
		# Every retained record observes the timestamp, while only active participation consumes it.
		var elapsed_ticks: int = clock.step_ticks
		if person.cadence_sample_tick >= 0:
			elapsed_ticks = maxi(0, clock.elapsed_ticks - person.cadence_sample_tick)
			person.cadence_sample_tick = clock.elapsed_ticks

		var actor: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
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
		if person.cadence_sample_tick < 0:
			var stagger: float = DecisionRandomRules.generator(
				clock.world_seed, String(person.npc_id), cycle.day_index, "npc/cadence_stagger",
			).randf()
			person.cadence_elapsed_ticks = floori(stagger * float(interval_ticks))
			person.cadence_sample_tick = clock.elapsed_ticks
		person.cadence_elapsed_ticks += elapsed_ticks
		if person.cadence_elapsed_ticks >= interval_ticks:
			decision.scheduled_delta = GameTimeRules.seconds(person.cadence_elapsed_ticks)
			person.cadence_elapsed_ticks = 0
			decision.scheduled_day = cycle.day_index
			decision.scheduled_phase = int(cycle.phase)
#endregion
