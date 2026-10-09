extends System
## Owns persisted AI cadence against the session timestamp and captures one shared native interval.
class_name S_NpcCadence


#region Scheduling
## Eligibility follows district/customer commits and precedes all sampled AI work.
func deps() -> Dictionary[int, Array]:
	return {
		Runs.After: [S_GameTime, S_District, S_DayPhase],
		Runs.Before: [S_NpcFootsteps, S_NpcPerception, S_NpcTraits, S_NpcDecision],
	}


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
func _select_due(
	session_reference: WeakRef,
	captured_district: C_District,
	captured_cycle: C_DayCycle,
) -> void:
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
	var due_people: Array[NpcRecord] = []
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
		assert(
			decision != null and actor.has_component(C_NpcAwareness),
			"Retained NPCs require their compiled brain capability",
		)
		decision.scheduled_delta = 0.0
		if (
			cycle.phase == C_DayCycle.Phase.NIGHT or person.death_day != 0 \
					or person.placement != NpcRecord.Placement.STREET
			or not actor.enabled
		):
			decision.due_since_tick = -1
			continue

		assert(
			actor.get_node_or_null("Brain") is BTPlayer,
			"Active participation requires completed passive engine binding",
		)
		if person.cadence_sample_tick < 0:
			var cadence_random: RandomNumberGenerator = DecisionRandomRules.generator(
				clock.world_seed,
				String(person.npc_id),
				cycle.day_index,
				"npc/cadence_stagger",
			)
			var stagger: float = cadence_random.randf()
			person.cadence_elapsed_ticks = floori(stagger * float(interval_ticks))
			person.cadence_sample_tick = clock.elapsed_ticks
		person.cadence_elapsed_ticks += elapsed_ticks
		if person.cadence_elapsed_ticks >= interval_ticks or decision.wake_requested:
			if decision.due_since_tick < 0:
				decision.due_since_tick = clock.elapsed_ticks
			district.decision_max_wait_ticks = maxi(
				district.decision_max_wait_ticks,
				clock.elapsed_ticks - decision.due_since_tick,
			)
			decision.selection_reason = &"budget_deferred"
			due_people.append(person)

	# Stable IDs preserve fairness across archetype order and roster insertion/removal.
	due_people.sort_custom(_identity_before)
	district.decisions_due = due_people.size()
	district.decisions_processed = mini(
		maxi(1, district.definition.decision_work_units),
		due_people.size(),
	)
	district.decisions_deferred = district.decisions_due - district.decisions_processed
	var first_index: int = 0
	for index: int in due_people.size():
		if String(due_people[index].npc_id) > String(district.decision_cursor):
			first_index = index
			break
	for offset: int in district.decisions_processed:
		var person: NpcRecord = due_people[(first_index + offset) % due_people.size()]
		var actor: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
		decision.scheduled_delta = maxf(
			GameTimeRules.seconds(person.cadence_elapsed_ticks),
			GameTimeRules.seconds(clock.step_ticks),
		)
		decision.scheduled_day = cycle.day_index
		decision.scheduled_phase = int(cycle.phase)
		var selected_reason: StringName = decision.wake_reason if decision.wake_requested \
				else &"cadence_due"
		decision.selection_reason = selected_reason
		decision.obligation_source = "%s/day=%d/phase=%d" % [
			person.profile.schedule.resource_path,
			person.planned_day,
			person.planned_phase,
		]
		decision.wake_requested = false
		decision.wake_urgent = false
		decision.wake_reason = &""
		decision.due_since_tick = -1
		person.cadence_elapsed_ticks = 0
		district.decision_cursor = person.npc_id


func _identity_before(first: NpcRecord, second: NpcRecord) -> bool:
	return String(first.npc_id) < String(second.npc_id)
#endregion
