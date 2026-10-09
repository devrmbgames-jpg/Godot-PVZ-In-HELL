extends "res://tests/gut/test_district_plan_acceptance.gd"
## Verifies real AI stage ordering, shared due intervals and queued/reentrant lifecycle gates.


## Records committed sensing at the actual native-decision publication boundary.
class ReadyRecorder extends Observer:
	## Observed second-body visibility at every decision publication.
	var sampled: Array[bool] = []
	## Exact accumulated intervals consumed by the production decision owner.
	var intervals: Array[float] = []
	var _second: E_DistrictNpc
	var _retire: bool = false


	#region Boundary recording
	## Configures a retained fixture body and optional synchronous death reaction.
	func configure(second: E_DistrictNpc, retire: bool = false) -> void:
		_second = second
		_retire = retire


	## Watches the same typed fact as the role clock.
	func query() -> QueryBuilder:
		return q.with_all([C_NpcDecision]).on_event(NpcDecisionReady.EVENT)


	## Records what a synchronous consumer sees and may end participation reentrantly.
	func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
		var fact: NpcDecisionReady = payload as NpcDecisionReady
		intervals.append(fact.delta_seconds)
		sampled.append((_second.get_component(C_NpcAwareness) as C_NpcAwareness).player_visible)
		if _retire:
			entity.add_component(C_Death.new())
	#endregion


#region Fixture graph
func _owners() -> Array[System]:
	var owners: Array[System] = []
	# Deliberately register backwards so only deps define the execution order.
	for owner_type: Script in [
		S_NpcNoise,
		S_NpcRoutePlanning,
		S_NpcRoute,
		S_NpcDecision,
		S_NpcTraits,
		S_NpcPerception,
		S_NpcFootsteps,
		S_NpcCadence,
		S_GameTime,
	]:
		var owner: System = owner_type.new() as System
		owner.group = "npc_scheduling"
		owners.append(owner)
	_world.add_systems(owners, true)
	return owners


func _isolate(first_index: int = 0, second_index: int = 3) -> void:
	for index: int in _district.people.size():
		# These interval fixtures start after bootstrap rather than consuming its authored wake.
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[index].npc_id)
		var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
		decision.wake_requested = false
		decision.wake_urgent = false
		if index != first_index and index != second_index:
			var person: NpcRecord = _district.people[index]
			DistrictPopulationService.set_placement(
				person,
				NpcPopulationQueries.body_for(person.npc_id),
				NpcRecord.Placement.HOME,
			)
#endregion


#region Shared due-step ordering
## All due sight samples precede either native decision and consume one accumulated interval.
func test_all_due_sensors_commit_before_either_native_decision() -> void:
	_isolate()
	var first: E_DistrictNpc = _stage(0, Vector3(-2, 0, 0))
	var second: E_DistrictNpc = _stage(3, Vector3(2, 0, 0))
	_player(Vector3(0, 0, -3))
	_district.definition = _district.definition.duplicate() as DEF_District
	_district.definition.decision_interval = 0.3
	for actor: E_DistrictNpc in [first, second]:
		var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
		NpcPopulationQueries.person_for(identity.npc_id).cadence_elapsed_ticks = 0
		NpcPopulationQueries.person_for(identity.npc_id).cadence_sample_tick = 0
	var recorder: ReadyRecorder = ReadyRecorder.new()
	recorder.configure(second)
	_world.add_observer(recorder)
	_owners()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_world.process(0.1, "npc_scheduling")
	assert_eq(recorder.intervals.size(), 0)
	_world.process(0.2, "npc_scheduling")
	assert_eq(recorder.intervals.size(), 2)
	assert_true(
		recorder.sampled.all(
			func(visible: bool) -> bool:
				return visible,
		)
	)
	for interval: float in recorder.intervals:
		assert_almost_eq(interval, 0.3, 0.001)
	_world.process(0.1, "npc_scheduling")
	assert_eq(recorder.intervals.size(), 2)


## Noise is sampled before its same-step expiration, then removed by its sole ageing owner.
func test_noise_expires_only_after_due_hearing_consumers() -> void:
	_isolate(0, 0)
	var actor: E_DistrictNpc = _stage(0)
	var player: E_DistrictNpc = _player()
	_district.people[0].cadence_elapsed_ticks = 0
	_district.people[0].cadence_sample_tick = 0
	NpcPerceptionService.emit_noise(player, player.global_position, 100.0)
	_district.noises.back().remaining = 0.01
	_owners()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_world.process(_district.definition.decision_interval, "npc_scheduling")
	assert_gt((actor.get_component(C_NpcAwareness) as C_NpcAwareness).heard_remaining, 0.0)
	assert_true(_district.noises.is_empty())


## Pausing the clock cannot re-publish a due decision from the previous complete step.
func test_paused_clock_cannot_replay_the_previous_due_decision() -> void:
	_isolate(0, 0)
	var actor: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	person.cadence_elapsed_ticks = 0
	person.cadence_sample_tick = 0
	var recorder: ReadyRecorder = ReadyRecorder.new()
	recorder.configure(actor)
	_world.add_observer(recorder)
	_owners()
	var interval: float = _district.definition.decision_interval
	_world.process(interval, "npc_scheduling")
	assert_eq(recorder.intervals.size(), 1)

	var cycle: C_DayCycle = DayPhaseQueries.current()
	var previous_tick: int = cycle.clock.elapsed_ticks
	cycle.clock.paused = true
	_world.process(0.0, "npc_scheduling")
	assert_eq(recorder.intervals.size(), 1)
	assert_eq((actor.get_component(C_NpcDecision) as C_NpcDecision).scheduled_delta, 0.0)
	assert_eq(cycle.clock.elapsed_ticks, previous_tick)
	assert_eq(person.cadence_elapsed_ticks, 0)

	cycle.clock.paused = false
	_world.process(interval, "npc_scheduling")
	assert_eq(recorder.intervals.size(), 2)


## Night and dormant participation freeze interval/noise progression without a second scheduler.
func test_night_and_dormant_bodies_do_not_advance_ai_clocks() -> void:
	_isolate(0, 0)
	var actor: E_DistrictNpc = _stage(0)
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	_district.people[0].cadence_elapsed_ticks = 0
	_district.people[0].cadence_sample_tick = 0
	NpcPerceptionService.emit_noise(actor, actor.global_position, 20.0)
	var remaining: float = _district.noises[0].remaining
	_owners()
	DayPhaseQueries.current().phase = C_DayCycle.Phase.NIGHT
	_world.process(1.0, "npc_scheduling")
	assert_eq(_district.people[0].cadence_elapsed_ticks, 0)
	assert_eq(_district.noises[0].remaining, remaining)
	DayPhaseQueries.current().phase = C_DayCycle.Phase.MORNING
	DistrictPopulationService.set_placement(_district.people[0], actor, NpcRecord.Placement.HOME)
	_world.process(1.0, "npc_scheduling")
	assert_eq(_district.people[0].cadence_elapsed_ticks, 0)
	assert_eq(decision.scheduled_delta, 0.0)
#endregion


#region Queued and reentrant boundaries
## A queued sensor stage cannot advance a replacement decision component.
func test_pending_sensor_rejects_replaced_due_component() -> void:
	var actor: E_DistrictNpc = _stage(0)
	var awareness: C_NpcAwareness = actor.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.heard_remaining = 3.0
	var captured: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	captured.scheduled_delta = 0.2
	captured.scheduled_day = 1
	captured.scheduled_phase = int(C_DayCycle.Phase.MORNING)
	var sensor: S_NpcPerception = S_NpcPerception.new()
	sensor.group = "queued_sensor"
	sensor.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(sensor)
	_world.process(0.0, sensor.group)
	actor.remove_component(C_NpcDecision)
	var replacement: C_NpcDecision = C_NpcDecision.new()
	replacement.scheduled_delta = 0.2
	replacement.scheduled_day = 1
	replacement.scheduled_phase = int(C_DayCycle.Phase.MORNING)
	actor.add_component(replacement)
	_world.flush_command_buffers()
	assert_eq(awareness.heard_remaining, 3.0)


## A synchronous ready consumer may retire the actor before native BT starts.
func test_ready_consumer_death_prevents_later_native_update() -> void:
	_isolate(0, 0)
	var actor: E_DistrictNpc = _stage(0)
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	_district.people[0].cadence_elapsed_ticks = 0
	_district.people[0].cadence_sample_tick = 0
	var recorder: ReadyRecorder = ReadyRecorder.new()
	recorder.configure(actor, true)
	_world.add_observer(recorder)
	_owners()
	_world.process(_district.definition.decision_interval, "npc_scheduling")
	assert_eq(recorder.intervals.size(), 1)
	assert_eq(_district.people[0].death_day, 1)
	assert_false(actor.enabled)
	assert_eq(decision.scheduled_delta, 0.0)
	assert_eq(decision.active_task_id, 0)


## A route queued while live cannot advance clocks after the body leaves participation.
func test_pending_route_rejects_departed_body() -> void:
	var actor: E_DistrictNpc = _stage(0)
	var person: NpcRecord = _district.people[0]
	var route: C_NpcRoute = actor.get_component(C_NpcRoute) as C_NpcRoute
	route.elapsed = 0.2
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	decision.scheduled_delta = 2.0
	decision.scheduled_day = 1
	decision.scheduled_phase = int(C_DayCycle.Phase.MORNING)
	NpcIntentService.move_to(actor, Vector3(20, 0, 0), 0.3)
	var owner: S_NpcRoute = S_NpcRoute.new()
	owner.group = "queued_route"
	owner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(owner)
	_world.process(0.0, owner.group)
	DistrictPopulationService.set_placement(person, actor, NpcRecord.Placement.HOME)
	assert_same(actor.get_component(C_NpcRoute), route)
	var elapsed_after_departure: float = route.elapsed
	_world.flush_command_buffers()
	assert_eq(route.elapsed, elapsed_after_departure)
	assert_false(route.pending)
	assert_eq(person.placement, NpcRecord.Placement.HOME)


## A queued budget operation cannot mutate an aggregate replaced before its commit.
func test_pending_planner_rejects_replaced_district_aggregate() -> void:
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	_district.pending_routes.append(_district.people[0].npc_id)
	var planner: S_NpcRoutePlanning = S_NpcRoutePlanning.new()
	planner.group = "queued_planning"
	planner.command_buffer_flush_mode = System.FlushMode.MANUAL
	_world.add_system(planner)
	_world.process(0.0, planner.group)
	session.remove_component(C_District)
	var replacement: C_District = C_District.new()
	session.add_component(replacement)
	_world.flush_command_buffers()
	assert_eq(_district.pending_routes.size(), 1)
	assert_eq(_district.route_planning_frame, -1)
	assert_eq(replacement.route_planning_frame, -1)
#endregion
