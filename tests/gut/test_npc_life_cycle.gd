extends "res://tests/gut/test_npc_authored_population.gd"
## Действительные смерти, календарь и persisted партия каждой жизни авторского пилота.

const STREET_DEATH_DISTANCE: float = 5.0
const GUEST_PILOT_PATH: String = (
	"res://content/domains/npc/definitions/def_district_lost_life_prototype.tres"
)


#region Native damage fixture
func _make_world() -> World:
	return GameWorld.new()


func before_each() -> void:
	super.before_each()
	var session: Entity = _world.query.with_all([C_District, C_DayCycle]).execute_one()
	session.add_component(C_LootDrops.new())
	_world.add_observer(O_Damage.new())
	_world.add_observer(O_HealthLifecycle.new())
	_world.add_observer(O_NpcRemains.new())
	for person: NpcRecord in _district.people:
		NpcPopulationQueries.body_for(person.npc_id).set_physics_process(false)


func _kill(person: NpcRecord) -> E_DistrictNpc:
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	# Реальная добыча остаётся на месте смерти; свободный дом проверяется отдельно.
	var origin: StringName = person.home_id if person.profile.resident else person.portal_id
	var street: Vector3 = NpcPopulationQueries.position_for(origin, true) + Vector3(
		0,
		0,
		STREET_DEATH_DISTANCE * (person.deaths.size() + 1),
	)
	assert_true(
		DistrictPopulationService.set_placement(
			person,
			body,
			NpcRecord.Placement.STREET,
			&"test_street_death",
			false,
			street,
		)
	)
	var request: DamageRequest = DamageRequest.new()
	request.target = body
	request.amount = (body.get_component(C_Health) as C_Health).value * 2.0
	DamageRequestService.submit(request)
	assert_true(body.has_component(C_Death))
	assert_eq(person.death_day, DayPhaseQueries.current().day_index)
	return body


func _morning(day: int) -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = day
	cycle.phase = C_DayCycle.Phase.MORNING
	var receipt: DistrictMorningPreparationRequest = DistrictPopulationService.prepare_morning(day)
	assert_true(receipt.completed and receipt.succeeded)


func _queue() -> C_LootDrops:
	return LootDropService.current()
#endregion


#region Calendar, identity and one batch per death
func test_death_waits_two_calendar_days_and_returns_the_same_body_once() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	NpcDialogueMemoryService.set_tag(person, &"visited")
	NpcDialogueMemoryService.set_val(person, &"quest_stage", 4)
	var previous_help: NpcMemory = NpcMemory.new()
	previous_help.incident_id = &"test/previous_help"
	previous_help.actor_id = &"player"
	previous_help.victim_id = person.npc_id
	person.memories.append(previous_help)
	var body: E_DistrictNpc = _kill(person)
	var npc_id: StringName = person.npc_id
	var home_id: StringName = person.home_id
	var name_before: String = person.display_name
	var batches: int = _queue().committed_batches.size()
	assert_eq(person.deaths.size(), 1)
	assert_eq(person.deaths[0].day, 1)
	assert_true(_queue().committed_batches.has("npc/3/death/1/remains"))
	DistrictPopulationService.mark_dead(person, body, 1)
	NpcRemainsService.release(body)
	assert_eq(person.deaths.size(), 1)
	assert_eq(_queue().committed_batches.size(), batches)
	GameTimeQueries.current().elapsed_ticks += 100000000000
	assert_false(NpcLifeRules.return_due(person, 2))
	_morning(2)
	assert_eq(person.death_day, 1)
	assert_true(body.has_component(C_Death))
	assert_false(body.enabled)
	_morning(3)
	assert_same(NpcPopulationQueries.body_for(npc_id), body)
	assert_same(NpcPopulationQueries.person_for(npc_id), person)
	assert_eq(person.home_id, home_id)
	assert_eq(person.display_name, name_before)
	assert_eq(person.death_day, 0)
	assert_eq(person.deaths[0].returned_day, 3)
	assert_false(body.has_component(C_Death))
	var health: C_Health = body.get_component(C_Health) as C_Health
	assert_false(health.depleted)
	assert_eq(health.current, health.value)
	assert_true(person.dialogue_tags[&"visited"])
	assert_eq(person.dialogue_values[&"quest_stage"], 4)
	assert_true(
		person
		.memories
		.any(
			func(memory: NpcMemory) -> bool:
				return (
					memory.incident_id == &"test/previous_help"
					and memory.actor_id == &"player" and memory.victim_id == person.npc_id
					and memory.kind == NpcMemory.Kind.HELP and memory.day == 1
				),
		)
	)
	assert_eq(_queue().committed_batches.size(), batches)
	_morning(3)
	assert_eq(person.deaths.size(), 1)
	assert_eq(_district.people.size(), 3)
	assert_true(WorldSnapshotService.can_restore(WorldSnapshotService.capture(_root, 3), _root))


func test_old_queued_death_cannot_terminate_the_returned_life() -> void:
	var lifecycle: O_DistrictLifecycle = null
	for observer: Observer in _world.observers:
		if observer is O_DistrictLifecycle:
			lifecycle = observer as O_DistrictLifecycle
	assert_not_null(lifecycle)
	if lifecycle == null:
		return
	lifecycle.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var street: Vector3 = NpcPopulationQueries.position_for(person.home_id, true) + Vector3(
		0,
		0,
		STREET_DEATH_DISTANCE,
	)
	assert_true(
		DistrictPopulationService.set_placement(
			person,
			body,
			NpcRecord.Placement.STREET,
			&"test_deferred_death",
			false,
			street,
		)
	)
	var request: DamageRequest = DamageRequest.new()
	request.target = body
	request.amount = (body.get_component(C_Health) as C_Health).value * 2.0
	DamageRequestService.submit(request)
	assert_true(body.has_component(C_Death))
	assert_true(lifecycle.has_pending_commands())
	DistrictPopulationService.mark_dead(person, body, 1)
	DayPhaseQueries.current().day_index = 3
	assert_eq(DistrictPopulationService.return_due(_district, 3).size(), 1)
	lifecycle.cmd.execute()
	lifecycle.command_buffer_flush_mode = Observer.FlushMode.PER_CALLBACK
	assert_eq(person.death_day, 0)
	assert_eq(person.deaths.size(), 1)
	assert_false(body.has_component(C_Death))


func test_second_death_creates_a_new_batch_and_keeps_the_first_episode() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _kill(person)
	_morning(3)
	assert_same(_kill(person), body)
	assert_eq(person.deaths.size(), 2)
	if person.deaths.size() != 2:
		return
	assert_eq(person.deaths[0].day, 1)
	assert_eq(person.deaths[0].returned_day, 3)
	assert_eq(person.deaths[1].sequence, 2)
	assert_eq(person.deaths[1].day, 3)
	assert_true(_queue().committed_batches.has("npc/3/death/1/remains"))
	assert_true(_queue().committed_batches.has("npc/3/death/2/remains"))
	assert_eq(_queue().committed_batches.size(), 2)
	NpcRemainsService.release(body)
	assert_eq(_queue().committed_batches.size(), 2)
	_morning(4)
	assert_eq(person.death_day, 3)
	_morning(5)
	assert_eq(person.deaths[1].returned_day, 5)
	assert_eq(person.death_day, 0)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)


func test_death_on_day_seven_returns_on_nine_and_living_sleep_does_not_heal() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var health: C_Health = body.get_component(C_Health) as C_Health
	health.current = 41.0
	_morning(7)
	assert_eq(health.current, 41.0)
	assert_true(person.deaths.is_empty())
	_kill(person)
	_morning(8)
	assert_eq(person.death_day, 7)
	_morning(9)
	assert_eq(person.death_day, 0)
	assert_eq(person.deaths[0].day, 7)
	assert_eq(person.deaths[0].returned_day, 9)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)


func test_invalid_death_history_or_missing_retained_body_rejects_without_live_mutation() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _kill(person)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	for invalid: String in ["sequence", "day", "early_return", "missing_body"]:
		var malformed: Dictionary = snapshot.duplicate(true)
		var body_record: Dictionary = { }
		for record: Dictionary in malformed.entities:
			if String(record.key) == String(person.npc_id):
				body_record = record
			for data: Dictionary in record.components:
				if String(data.type) != C_District.resource_path:
					continue
				for encoded_person: Dictionary in data.fields.people:
					if String(encoded_person.fields.npc_id) != String(person.npc_id):
						continue
					var fields: Dictionary = encoded_person.fields.deaths[0].fields as Dictionary
					match invalid:
						"sequence":
							fields.sequence = 2
						"day":
							fields.day = 0
						"early_return":
							fields.returned_day = 2
		if invalid == "missing_body":
			(malformed.entities as Array).erase(body_record)
		assert_false(WorldSnapshotService.restore(malformed, _root), invalid)
		assert_same(NpcPopulationQueries.person_for(person.npc_id), person)
		assert_same(NpcPopulationQueries.body_for(person.npc_id), body)


func test_night_death_uses_actual_calendar_day_and_roundtrips_while_absent() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.NIGHT
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _kill(person)
	_morning(2)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	var restored: NpcRecord = NpcPopulationQueries.person_for(person.npc_id)
	assert_same(NpcPopulationQueries.body_for(restored.npc_id), body)
	assert_eq(restored.death_day, 1)
	assert_eq(restored.deaths.size(), 1)
	assert_eq(restored.deaths[0].returned_day, 0)
	assert_eq(_queue().committed_batches.size(), 1)
	_morning(3)
	assert_eq(restored.death_day, 0)
	assert_eq(restored.deaths[0].returned_day, 3)
	assert_eq(_queue().committed_batches.size(), 1)


func test_blocked_home_keeps_death_pending_until_safe_calendar_retry() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _kill(person)
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 3.0)
	collision.shape = shape
	blocker.add_child(collision)
	_root.add_child(blocker)
	blocker.global_position = NpcPopulationQueries.position_for(person.home_id, true) + Vector3.UP
	await get_tree().physics_frame
	_morning(3)
	assert_eq(person.death_day, 1)
	assert_eq(person.deaths[0].returned_day, 0)
	assert_true(body.has_component(C_Death))
	assert_true((body.get_component(C_Health) as C_Health).depleted)
	blocker.free()
	await get_tree().physics_frame
	# Existing discrete phase reconciliation retries due returns; no new polling System is used.
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	DistrictPopulationService.reconcile_calendar(_world, session)
	assert_eq(person.death_day, 0)
	assert_eq(person.deaths[0].returned_day, 3)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)


func test_returning_lost_guest_keeps_identity_and_memory_without_a_home() -> void:
	var session: Entity = _world.query.with_all([C_District, C_DayCycle]).execute_one()
	# New isolated campaign, not migration of the resident fixture's people or recipients.
	for actor: Entity in _world.entities.duplicate():
		if actor != session:
			_world.remove_entity(actor)
	_district.definition = load(GUEST_PILOT_PATH)
	_district.people.clear()
	_district.next_person = 1
	_district.prepared_morning = 0
	_district.lifecycle_day = 0
	_district.lifecycle_phase = -1
	assert_true(DistrictPopulationService.initialize())
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/20")
	assert_true(person.home_id.is_empty())
	assert_false(person.profile.resident)
	NpcDialogueMemoryService.set_tag(person, &"previous_visit")
	var body: E_DistrictNpc = _kill(person)
	_morning(2)
	assert_false(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET))
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	var restored: NpcRecord = NpcPopulationQueries.person_for(&"npc/20")
	_morning(3)
	assert_eq(restored.death_day, 0)
	assert_eq(restored.deaths[0].returned_day, 3)
	assert_true(restored.home_id.is_empty())
	assert_true(restored.dialogue_tags[&"previous_visit"])
	assert_same(NpcPopulationQueries.body_for(restored.npc_id), body)
	assert_eq(NpcPopulationQueries.current().people.size(), 1)
	assert_eq(NpcPopulationQueries.current().next_person, 21)


func test_night_write_retry_keeps_one_return_and_one_immutable_snapshot() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _kill(person)
	_morning(2)
	var session: Entity = _world.query.with_all([C_District, C_DayCycle]).execute_one()
	var state: C_Autosave = C_Autosave.new()
	state.path = "user://gut_npc_life_retry_missing/slot.pvzh"
	assert_false(
		DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(state.path.get_base_dir()))
	)
	session.add_component(state)
	DayPhaseQueries.current().phase = C_DayCycle.Phase.NIGHT
	_world.add_system(S_NightSave.new())
	for attempt: int in 24:
		_world.process(0.1, "Storage")
		if not state.prepared_snapshot.is_empty():
			break
	assert_false(state.prepared_snapshot.is_empty())
	if state.prepared_snapshot.is_empty():
		return
	assert_ne(state.last_error, OK)
	assert_ne(state.last_error, ERR_INVALID_DATA)
	assert_eq(person.death_day, 0)
	assert_eq(person.deaths[0].returned_day, 3)
	var prepared: Dictionary = state.prepared_snapshot.duplicate(true)
	var health: C_Health = body.get_component(C_Health) as C_Health
	health.current = 77.0
	for attempt: int in 3:
		state.retry_remaining = 0.0
		_world.process(0.1, "Storage")
		assert_eq(state.prepared_snapshot, prepared)
		assert_eq(person.deaths.size(), 1)
		assert_eq(health.current, 77.0)
		assert_eq(_queue().committed_batches.size(), 1)
	state.path = SAVE_PATH
	state.retry_remaining = 0.0
	_world.process(0.1, "Storage")
	assert_eq(state.last_error, OK)
	assert_true(DayPhaseQueries.current().night_ready)
	_morning(3)
	assert_eq(health.current, 77.0)
	assert_eq(person.deaths.size(), 1)
#endregion
