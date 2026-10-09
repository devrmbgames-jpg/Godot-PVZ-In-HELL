extends "res://tests/gut/test_district_population.gd"
## Snapshot отсутствующих NPC: сохранность личности/тела/инвентаря и отказ повреждённых районных данных.

#region Согласованный snapshot
## Восстановление сохраняет ранения и вещи отсутствующего NPC, очищая производное восприятие.
func test_absent_person_roundtrip_preserves_body_state_and_resets_brain() -> void:
	_world.add_observer(O_InventoryLifecycle.new())
	DistrictPopulationService.prepare_morning(2)
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var health: C_Health = body.get_component(C_Health) as C_Health
	health.current = 41.0
	var meat: DEF_InventoryItem = load("res://content/domains/inventory/definitions/def_item_npc_meat.tres") as DEF_InventoryItem
	assert_true(InventoryService.grant(body, meat, 3))

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.heard_remaining = 100.0
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	health.current = 90.0
	assert_true(WorldSnapshotService.restore(snapshot, _root))

	var restored: NpcRecord = NpcPopulationQueries.person_for(person.npc_id)
	var restored_body: E_DistrictNpc = NpcPopulationQueries.body_for(restored.npc_id)
	assert_eq(restored.placement, NpcRecord.Placement.OUTSIDE)
	assert_eq((restored_body.get_component(C_Health) as C_Health).current, 41.0)
	assert_eq((restored_body.get_component(C_NpcAwareness) as C_NpcAwareness).heard_remaining, 0.0)
	DistrictPopulationService.set_placement(restored, restored_body, NpcRecord.Placement.STREET)
	assert_eq(InventoryService.items(restored_body).size(), 1)
	assert_eq((InventoryService.items(restored_body)[0].get_component(C_InventoryItem) as C_InventoryItem).quantity, 3)
	assert_true(WorldSnapshotService.restore(snapshot, _root))

	var matches: int = 0
	for entity: Entity in _world.entities:
		var identity: C_NpcIdentity = entity.get_component(C_NpcIdentity) as C_NpcIdentity
		if identity != null and identity.npc_id == restored.npc_id:
			matches += 1
	assert_eq(matches, 1)

## Дубликат постоянной личности отклоняется до изменения живого мира.
func test_duplicate_person_snapshot_is_rejected() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	for record: Dictionary in snapshot.entities:
		for component: Dictionary in record.components:
			if component.type == C_District.resource_path:
				var entries: Array = component.fields.people as Array
				entries.append(entries[0])
	assert_false(WorldSnapshotService.valid(snapshot, _root))
	assert_eq(_district.people.size(), 12)

## Подтверждённое преследование блокирует сон; личная вражда после завершения поиска его не блокирует.
func test_sleep_returns_after_search_and_does_not_read_hostility() -> void:
	DayPhaseQueries.current().phase = C_DayCycle.Phase.EVENING
	var player_body: RigidBody3D = RigidBody3D.new()
	player_body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var player: Entity = player_body as Node as Entity
	player.component_resources = [C_PlayerInputController.new(), C_Health.new()]
	_world.add_entity(player)
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	CombatService.bind_target(body, player)

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.has_last_seen = true
	assert_false(NpcSleepService.blockers().is_empty())
	assert_true(DayPhaseService.shift_status(DayPhaseQueries.current()).contains(person.display_name))
	awareness.search_elapsed = person.profile.search_seconds
	CombatService.end_combat(body)
	NpcSocialService.remember(person, player, body, NpcMemory.Kind.THREAT, &"test/old_hostility")
	assert_true(NpcSleepService.blockers().is_empty())
	assert_eq(DayPhaseService.shift_status(DayPhaseQueries.current()), "Сон доступен")

## Повтор после ошибки ночной записи не дублирует заселение или память о нарушенном обещании.
func test_night_write_retry_keeps_replacement_and_promise_once() -> void:
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_CustomerFlow.new())
	session.add_component(C_Autosave.new())
	var person: NpcRecord = _district.people[3]
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"test/night_promise"
	visit.customer_id = person.npc_id
	visit.package_id = "test/night_promise_box"
	visit.definition = (load("res://content/domains/customers/definitions/def_customer_schedule_default.tres") as DEF_CustomerSchedule).events[0].customer
	CustomerFlowQueries.current().visits.append(visit)

	var job: NpcHomeDelivery = NpcHomeDelivery.new()
	job.job_id = &"test/night_job"
	job.npc_id = person.npc_id
	job.visit_id = visit.visit_id
	job.package_id = visit.package_id
	job.address_id = person.home_id
	job.order_number = 1
	job.day_index = 2
	job.deadline_day = 3
	_district.home_deliveries.append(job)
	DistrictPopulationService.mark_dead(_district.people[0], NpcPopulationQueries.body_for(_district.people[0].npc_id), 1)
	DistrictPopulationService.mark_dead(_district.people[1], NpcPopulationQueries.body_for(_district.people[1].npc_id), 1)

	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.NIGHT
	var state: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	state.path = "user://gut_district_missing_directory/slot.pvzh"
	_night_step(0.2)
	assert_ne(state.last_error, OK)
	assert_ne(state.last_error, ERR_INVALID_DATA)
	assert_false(cycle.night_ready)
	assert_eq(_district.people.size(), 13)
	assert_eq(job.status, NpcHomeDelivery.Status.FAILED)
	assert_eq(person.memories.size(), 1)

	var replacement_id: StringName = _district.people.back().npc_id
	state.path = "user://gut_district_night_retry.pvzh"
	state.retry_remaining = 0.0
	_night_step(0.2)
	assert_eq(state.last_error, OK)
	assert_true(cycle.night_ready)
	assert_eq(_district.people.size(), 13)
	assert_eq(_district.people.back().npc_id, replacement_id)
	assert_eq(person.memories.size(), 1)

	var snapshot: Dictionary = AutosaveStore.read(state.path)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(NpcPopulationQueries.person_for(_district.people[0].npc_id).death_day, 1)
	assert_eq(NpcPopulationQueries.current().home_deliveries[0].order_number, 1)
	assert_eq(NpcPopulationQueries.current().people.back().npc_id, replacement_id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.path))
#endregion

#region Scheduled persistence fixture
func _night_step(delta: float) -> void:
	var installed: bool = false
	for owner: System in _world.systems:
		if owner is S_NightSave:
			installed = true
	if not installed:
		var night_owner: S_NightSave = S_NightSave.new()
		night_owner.group = "PersistenceTest"
		_world.add_system(night_owner)
	_world.process(delta, "PersistenceTest")
#endregion

#region Fresh body recipe restoration
## A missing NPC compiles saved roster/Profile inputs and damaged health before native publication.
func test_missing_body_restore_publishes_saved_identity_and_health_before_consumers() -> void:
	var person: NpcRecord = _district.people[0]
	var npc_id: StringName = person.npc_id
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
	(body.get_component(C_Health) as C_Health).current = 37.0
	(body.get_component(C_Hunger) as C_Hunger).value = 73.0
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	_world.remove_entity(body)
	await get_tree().process_frame
	assert_null(NpcPopulationQueries.body_for(npc_id))
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	var publications: Array[StringName] = []
	_world.entity_added.connect(func(actor: Entity) -> void:
		var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
		if identity == null or identity.npc_id != npc_id:
			return
		var persistent: C_PersistentIdentity = actor.get_component(C_PersistentIdentity) \
			as C_PersistentIdentity
		assert_eq(persistent.key, String(npc_id))
		assert_eq((actor.get_component(C_Health) as C_Health).current, 37.0)
		assert_eq((actor.get_component(C_Hunger) as C_Hunger).value, 73.0)
		assert_true(actor.has_component(C_Inventory))
		assert_true(actor.has_component(C_InteractionActionSet))
		assert_eq((actor.get_component(C_Motion) as C_Motion).max_speed, person.profile.move_speed)
		publications.append(identity.npc_id))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(publications, [npc_id])
	var recreated: E_DistrictNpc = NpcPopulationQueries.body_for(npc_id)
	assert_not_null(recreated)
	assert_eq((recreated.get_component(C_Health) as C_Health).current, 37.0)
	assert_eq((recreated.get_component(C_Hunger) as C_Hunger).value, 73.0)
#endregion

#region Persistent home reconstruction
## A fresh restored door publishes the saved home key and authored label together.
func test_missing_address_restore_publishes_home_identity_and_label() -> void:
	var home: DEF_DistrictPlace = _places_of(DEF_DistrictPlace.Kind.HOME)[0]
	var address: Entity = _address_for(home.key)
	assert_not_null(address)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	_world.remove_entity(address)
	await get_tree().process_frame
	assert_null(_address_for(home.key))
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))

	var publications: Array[StringName] = []
	_world.entity_added.connect(func(actor: Entity) -> void:
		var identity: C_NpcAddress = actor.get_component(C_NpcAddress) as C_NpcAddress
		if identity == null:
			return
		assert_eq(identity.address_id, home.key)
		assert_eq((actor.get_node("Address") as Label3D).text, home.display_name)
		publications.append(identity.address_id))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(publications, [home.key])
	assert_not_null(_address_for(home.key))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(publications, [home.key], "In-place restore does not register a second door")


## Empty, unknown, non-home and duplicate home keys reject before live mutation.
func test_invalid_address_snapshot_preserves_live_homes() -> void:
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	var homes: Array[DEF_DistrictPlace] = _places_of(DEF_DistrictPlace.Kind.HOME)
	var portal: DEF_DistrictPlace = _places_of(DEF_DistrictPlace.Kind.PORTAL)[0]
	var retained: Entity = _address_for(homes[0].key)
	var count_before: int = _world.entities.size()
	for invalid_id: StringName in [&"", &"unknown/home", portal.key, homes[1].key]:
		var malformed: Dictionary = snapshot.duplicate(true)
		for record: Dictionary in malformed.entities:
			for component: Dictionary in record.components:
				if String(component.type) == (C_NpcAddress as Script).resource_path \
						and StringName(component.fields.address_id) == homes[0].key:
					component.fields.address_id = invalid_id
		assert_false(WorldSnapshotService.valid(malformed, _root))
		assert_false(WorldSnapshotService.restore(malformed, _root))
		assert_same(_address_for(homes[0].key), retained)
		assert_eq(_world.entities.size(), count_before)


func _places_of(kind: DEF_DistrictPlace.Kind) -> Array[DEF_DistrictPlace]:
	var matches: Array[DEF_DistrictPlace] = []
	for place: DEF_DistrictPlace in _district.definition.places:
		if place.kind == kind:
			matches.append(place)
	return matches


func _address_for(address_id: StringName) -> Entity:
	for actor: Entity in _world.entities:
		var identity: C_NpcAddress = actor.get_component(C_NpcAddress) as C_NpcAddress
		if identity != null and identity.address_id == address_id:
			return actor
	return null
#endregion
