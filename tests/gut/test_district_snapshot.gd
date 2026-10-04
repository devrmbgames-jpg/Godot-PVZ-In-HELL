extends "res://tests/gut/test_district_population.gd"
## Snapshot отсутствующих NPC: сохранность личности/тела/инвентаря и отказ повреждённых районных данных.

#region Согласованный snapshot
## Восстановление сохраняет ранения и вещи отсутствующего NPC, очищая производное восприятие.
func test_absent_person_roundtrip_preserves_body_state_and_resets_brain() -> void:
	_world.add_observer(O_InventoryLifecycle.new())
	DistrictPopulationService.prepare_morning(2)
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var health: C_Health = body.get_component(C_Health) as C_Health
	health.current = 41.0
	var meat: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_npc_meat.tres") as DEF_InventoryItem
	assert_true(InventoryService.grant(body, meat, 3))

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.heard_remaining = 100.0
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.valid(snapshot, _root))
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	health.current = 90.0
	assert_true(WorldSnapshotService.restore(snapshot, _root))

	var restored: NpcRecord = DistrictPopulationService.person_for(person.npc_id)
	var restored_body: E_DistrictNpc = DistrictPopulationService.body_for(restored.npc_id)
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
	DayPhaseService.current().phase = C_DayCycle.Phase.EVENING
	var player_body: RigidBody3D = RigidBody3D.new()
	player_body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var player: Entity = player_body as Node as Entity
	player.component_resources = [C_PlayerInputController.new(), C_Health.new()]
	_world.add_entity(player)
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	CombatService.bind_target(body, player)

	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.has_last_seen = true
	assert_false(NpcSleepService.blockers().is_empty())
	assert_true(DayPhaseService.shift_status(DayPhaseService.current()).contains(person.display_name))
	awareness.search_elapsed = person.profile.search_seconds
	CombatService.end_combat(body)
	NpcSocialService.remember(person, player, body, NpcMemory.Kind.THREAT, &"test/old_hostility")
	assert_true(NpcSleepService.blockers().is_empty())
	assert_eq(DayPhaseService.shift_status(DayPhaseService.current()), "Сон доступен")

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
	visit.definition = (load("res://content/definitions/gameplay/customers/def_customer_schedule_default.tres") as DEF_CustomerSchedule).events[0].customer
	CustomerFlowService.current().visits.append(visit)

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
	DistrictPopulationService.mark_dead(_district.people[0], DistrictPopulationService.body_for(_district.people[0].npc_id), 1)
	DistrictPopulationService.mark_dead(_district.people[1], DistrictPopulationService.body_for(_district.people[1].npc_id), 1)

	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.NIGHT
	var state: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	state.path = "user://gut_district_missing_directory/slot.pvzh"
	NightSaveService.process(session, cycle, state, 0.2)
	assert_ne(state.last_error, OK)
	assert_ne(state.last_error, ERR_INVALID_DATA)
	assert_false(cycle.night_ready)
	assert_eq(_district.people.size(), 13)
	assert_eq(job.status, NpcHomeDelivery.Status.FAILED)
	assert_eq(person.memories.size(), 1)

	var replacement_id: StringName = _district.people.back().npc_id
	state.path = "user://gut_district_night_retry.pvzh"
	state.retry_remaining = 0.0
	NightSaveService.process(session, cycle, state, 0.2)
	assert_eq(state.last_error, OK)
	assert_true(cycle.night_ready)
	assert_eq(_district.people.size(), 13)
	assert_eq(_district.people.back().npc_id, replacement_id)
	assert_eq(person.memories.size(), 1)

	var snapshot: Dictionary = AutosaveStore.read(state.path)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(DistrictPopulationService.person_for(_district.people[0].npc_id).death_day, 1)
	assert_eq(DistrictPopulationService.current().home_deliveries[0].order_number, 1)
	assert_eq(DistrictPopulationService.current().people.back().npc_id, replacement_id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state.path))
#endregion
