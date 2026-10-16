extends GutTest
## Real authored room bootstrap, isolated native population and daily receiving ownership.

var _level: Node3D


#region Native level lifetime
func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	_level = null
	await get_tree().process_frame


func _open(key: StringName) -> Node3D:
	var packed: PackedScene = load(GameSessionService.test_room_path(key)) as PackedScene
	var root: Node3D = packed.instantiate() as Node3D
	add_child(root)
	root.set_physics_process(false)
	_level = root
	return root
#endregion


#region Complete native day cycle
## Uses the authored console/sleep actions; never assigns the phase or day index.
func _room_transition(kind: DayTransitionRequest.Kind) -> bool:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var previous_phase: C_DayCycle.Phase = cycle.phase
	var path: String = "Entityes/ShiftConsole"
	if kind == DayTransitionRequest.Kind.SLEEP:
		path = "Entityes/SleepPoint"
	var station: Entity = _level.get_node(path) as Entity
	var actions: C_InteractionActionSet = station.get_component(C_InteractionActionSet)
	var action: DEF_DayPhaseAction = null
	for candidate: DEF_InteractionAction in actions.actions:
		if candidate is DEF_DayPhaseAction and (candidate as DEF_DayPhaseAction).transition == kind:
			action = candidate as DEF_DayPhaseAction
			break
	assert_not_null(action, path)
	if action == null:
		return false
	var player: Entity = _level.get_node("Entityes/Player") as Entity
	var available: bool = action.is_available(player, station, station)
	assert_true(available, DayPhaseService.shift_status(cycle))
	if not available:
		return false
	action.execute(player, station, station)
	for frame: int in 180:
		GameTimeFixture.gameplay(ECS.world, 1.0 / 60.0)
		if cycle.phase != previous_phase and cycle.phase != C_DayCycle.Phase.NIGHT:
			return true
		await get_tree().physics_frame
	var save: C_Autosave = ECS.world.query.with_all([C_Autosave]).execute_one().get_component(
		C_Autosave,
	) as C_Autosave
	assert_true(false, "Transition stuck: phase=%s error=%s" % [cycle.phase, save.last_error])
	return false


## Real nights must prepare fresh supplies and retain no disk save or detached snapshot.
func test_real_shift_and_sleep_reach_next_morning_without_save_slot() -> void:
	for key: StringName in GameSessionService.TEST_ROOM_KEYS:
		var root: Node3D = _open(key)
		var player: Node3D = root.get_node("Entityes/Player") as Node3D
		# Isolate the calendar from the separately tested hostile-archetype sleep safety rules.
		player.global_position = Vector3(30, 0.05, 25)
		var cycle: C_DayCycle = DayPhaseQueries.current()
		var session: Entity = ECS.world.query.with_all([C_Autosave]).execute_one()
		var save: C_Autosave = session.get_component(C_Autosave) as C_Autosave
		assert_eq(save.path, "", String(key))
		for day: int in [1, 2]:
			var today: Array[Entity] = []
			for frame: int in 600:
				GameTimeFixture.gameplay(ECS.world, 1.0 / 60.0)
				today.clear()
				for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
					var identity: C_Package = parcel.get_component(C_Package) as C_Package
					if identity.delivery_day == day:
						today.append(parcel)
				if today.size() == 2:
					break
				await get_tree().physics_frame
			assert_eq(today.size(), 2, "%s day%d: actual incoming supply" % [key, day])
			if today.size() != 2:
				return
			for index: int in today.size():
				var body: RigidBody3D = today[index] as Node as RigidBody3D
				body.freeze = true
				body.global_position = Vector3(0, 1, 6 + index * 2)
				var identity: C_Package = today[index].get_component(C_Package) as C_Package
				assert_true(CustomerFlowService.declare(
					StringName("visit/" + identity.package_id), CustomerVisit.Declaration.LOST,
				))
			await get_tree().physics_frame
			if not await _room_transition(DayTransitionRequest.Kind.START_SHIFT):
				return
			assert_eq(cycle.phase, C_DayCycle.Phase.DAY, String(key))
			# Complete appearances through their owner for this isolated calendar fixture.
			for visit: CustomerVisit in CustomerFlowQueries.current().visits.duplicate():
				if CustomerFlowQueries.visit_due(visit, day):
					CustomerVisitLifecycle.finish(visit, day)
			if not await _room_transition(DayTransitionRequest.Kind.FINISH_SHIFT):
				return
			assert_eq(cycle.phase, C_DayCycle.Phase.EVENING, String(key))
			if not await _room_transition(DayTransitionRequest.Kind.SLEEP):
				return
			assert_eq(cycle.phase, C_DayCycle.Phase.MORNING, String(key))
			assert_eq(cycle.day_index, day + 1, String(key))
			assert_eq(NpcPopulationQueries.current().prepared_morning, day + 1)
			assert_eq(save.last_saved_morning, 0, "No file save is claimed")
			assert_eq(save.last_prepared_morning, day + 1)
			assert_eq(save.last_error, OK)
			assert_true(save.prepared_snapshot.is_empty(), "No unused persistence snapshot")
		root.free()
		_level = null
		await get_tree().process_frame


## Empty storage destinations must not create a relative temporary file.
func test_empty_save_destination_is_rejected() -> void:
	assert_eq(AutosaveStore.write({ "probe": true }, ""), ERR_INVALID_PARAMETER)
#endregion


#region All authored isolated rooms
## The native supply must commit the resident's supported shopping preferences.
func test_room_orders_follow_resident_preferences() -> void:
	for key: StringName in GameSessionService.TEST_ROOM_KEYS:
		var root: Node3D = _open(key)
		var person: NpcRecord = NpcPopulationQueries.current().people[0]
		var zone: E_ReceivingZone = root.get_node("Entityes/ReceivingZone") as E_ReceivingZone
		var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
		var preferred_categories: int = 0
		for category: int in person.profile.item_category_weights:
			if person.profile.item_category_weights[category] > 0.0:
				preferred_categories |= category
		var available_categories: int = 0
		for item: DEF_InventoryItem in zone.supply.order_catalog:
			available_categories |= item.categories
		if not person.profile.item_category_weights.is_empty():
			assert_ne(preferred_categories & available_categories, 0, String(key))
		var first_orders: PackedStringArray = []
		for day: int in range(1, 4):
			ReceivingDeliveryService.prepare_batch(zone.supply, receiving, day)
			assert_eq(receiving.pending.size(), 1, String(key))
			var orders: PackedStringArray = receiving.pending[0].order_item_paths
			assert_eq(orders.size(), 2, "%s day%d" % [key, day])
			assert_true(
				ReceivingSnapshotRules.valid(receiving, zone), "%s day%d packing" % [key, day],
			)
			if day == 1:
				first_orders = orders.duplicate()
			for item_path: String in orders:
				var selected: DEF_InventoryItem = load(item_path) as DEF_InventoryItem
				assert_not_null(selected, String(key))
				if selected == null:
					continue
				if preferred_categories != 0:
					assert_ne(
						selected.categories & preferred_categories, 0,
						"%s: %s" % [key, selected.key],
					)
				if key == &"fire_elemental":
					assert_true(selected.key in [&"fire_flask", &"fire_barrel"])
				if key == &"vampire":
					assert_true(selected.key in [&"blood_flask", &"blood_barrel"])
		if key in [&"creepy", &"lost"]:
			var ordinary: DEF_Delivery = load(
				"res://content/domains/packages/definitions/def_delivery_morning_supply.tres",
			) as DEF_Delivery
			for item: DEF_InventoryItem in ordinary.order_catalog:
				assert_true(item in zone.supply.order_catalog, String(key))
		root.free()
		_level = null
		await get_tree().process_frame
		root = _open(key)
		zone = root.get_node("Entityes/ReceivingZone") as E_ReceivingZone
		receiving = zone.get_component(C_Receiving) as C_Receiving
		ReceivingDeliveryService.prepare_batch(zone.supply, receiving, 1)
		assert_eq(receiving.pending[0].order_item_paths, first_orders, "Repeatable fresh room")
		var preset: DEF_NpcTestRoom = load(
			"res://content/scenes/npc_test_rooms/def_npc_test_room_%s.tres" % key,
		) as DEF_NpcTestRoom
		assert_eq(preset.schedule.supply.order_catalog, zone.supply.order_catalog)
		root.free()
		_level = null
		await get_tree().process_frame


## Registered identities must also participate physically and be visible to the player.
func test_all_ten_room_npcs_start_visible_with_clear_activation_space() -> void:
	for key: StringName in GameSessionService.TEST_ROOM_KEYS:
		var root: Node3D = _open(key)
		for frame: int in 3:
			await get_tree().physics_frame
		var person: NpcRecord = NpcPopulationQueries.current().people[0]
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
		var context: String = "%s: placement=%s reason=%s" % [
			key, person.placement, decision.participation_reason,
		]
		assert_eq(person.placement, NpcRecord.Placement.STREET, context)
		assert_true(body.enabled, context)
		assert_true(body.is_visible_in_tree(), context)
		var spawn: Vector3 = NpcPopulationQueries.position_for(person.home_id, true)
		assert_true(NpcActivationSolver.available(body, spawn), context)
		root.free()
		_level = null
		await get_tree().process_frame


func test_three_daily_native_supplies_assign_both_registered_cases_to_the_only_resident() -> void:
	for key: StringName in GameSessionService.TEST_ROOM_KEYS:
		var root: Node3D = _open(key)
		var world: GameWorld = root.get("world") as GameWorld
		assert_false(world.initialization_failed(), String(key) + ": real room initialized")
		if world.initialization_failed():
			return
		var district: C_District = NpcPopulationQueries.current()
		var cycle: C_DayCycle = DayPhaseQueries.current()
		var zone: E_ReceivingZone = root.get_node("Entityes/ReceivingZone") as E_ReceivingZone
		var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
		for day: int in range(1, 4):
			cycle.day_index = day
			ReceivingDeliveryService.prepare_batch(zone.supply, receiving, day)
			root.set_physics_process(true)
			for frame: int in 900:
				if world.query.with_all([C_Package]).execute().size() == day * 2:
					break
				await get_tree().physics_frame
			root.set_physics_process(false)
			var parcels: Array[Entity] = world.query.with_all([C_Package]).execute()
			assert_eq(parcels.size(), day * 2, "%s day%d: two actual new bodies" % [key, day])
			var todays: int = 0
			for parcel: Entity in parcels:
				var identity: C_Package = parcel.get_component(C_Package) as C_Package
				if identity.delivery_day != day:
					continue
				todays += 1
				var contents: C_PackageContents = parcel.get_component(C_PackageContents)
				assert_not_null(contents.selected_item, "%s day%d: committed contents" % [key, day])
				var history: PackageRegistrationRecord = PackageHistoryService.record_for(
					identity.package_id,
				)
				assert_same(history.ordered_item, contents.selected_item)
				if day == 1 and todays == 1:
					var body: RigidBody3D = parcel as Node as RigidBody3D
					body.freeze = true
					body.global_position = Vector3(0, 1, 8)
					var condition: C_PackageState = parcel.get_component(C_PackageState)
					condition.opening = C_PackageState.Opening.OPENED
					var released: Array[Entity] = PackageContentsService.release(parcel)
					assert_eq(
						released.size() + LootDropService.current().pending.size(),
						contents.quantity,
						"%s: actual physical quantity" % key,
					)
					for item: Entity in released:
						assert_eq(
							item.scene_file_path, contents.selected_item.world_pickup_scene,
						)
						var inventory: C_InventoryItem = item.get_component(C_InventoryItem)
						assert_same(inventory.definition, contents.selected_item)
				var receipt: PackageScanResult = PackageRegistrationService.register_package(parcel)
				assert_eq(receipt.outcome, PackageScanResult.Outcome.ALREADY_REGISTERED)
				var visit: CustomerVisit = CustomerFlowQueries.find_visit(
					StringName("visit/" + identity.package_id)
				)
				assert_not_null(visit)
				if visit == null:
					continue
				assert_eq(visit.customer_id, district.people[0].npc_id)
				assert_eq(visit.arrival_day, day)
				assert_true(CustomerFlowQueries.arrival_allowed(visit))
				# Unload the real box to storage before the next day's physical receiving test.
				var stored_body: RigidBody3D = parcel as Node as RigidBody3D
				stored_body.freeze = true
				stored_body.global_position = Vector3(6 + (todays - 1) * 3, 1, 4 + day * 3)
			assert_eq(todays, 2, "%s day%d: both cases available for the same NPC" % [key, day])
			assert_eq(world.query.with_all([C_NpcIdentity]).execute().size(), 1)
		root.free()
		_level = null
		await get_tree().process_frame
		assert_null(ECS.world, "Room cleanup after three daily supplies")


func test_all_ten_rooms_bootstrap_exactly_one_canonical_npc_and_two_parcels() -> void:
	for key: StringName in GameSessionService.TEST_ROOM_KEYS:
		var root: Node3D = _open(key)
		var world: GameWorld = root.get("world") as GameWorld
		assert_false(
			world.initialization_failed(),
			String(key) + ": " + str(world.identity_issues()),
		)
		if world.initialization_failed():
			root.free()
			_level = null
			continue
		var district: C_District = NpcPopulationQueries.current()
		assert_not_null(district, String(key))
		if district == null:
			root.free()
			_level = null
			continue
		assert_eq(district.people.size(), 1, String(key))
		assert_eq(world.query.with_all([C_NpcIdentity]).execute().size(), 1, String(key))
		assert_eq(
			district.people[0].profile.key,
			(root.get_meta("npc_test_room") as DEF_NpcTestRoom).district.profiles[0].key,
		)
		var zone: E_ReceivingZone = root.get_node("Entityes/ReceivingZone") as E_ReceivingZone
		var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
		for day: int in range(1, 4):
			ReceivingDeliveryService.prepare_batch(zone.supply, receiving, day)
			assert_eq(receiving.incoming_package_ids.size(), 2, "%s day%d" % [key, day])
			assert_eq(receiving.pending.size(), 1)
			assert_eq(receiving.pending[0].package_keys.size(), 2)
			assert_eq(receiving.pending[0].day_index, day)
		assert_eq((root.get_node("Entityes/ReturnPortal") as Entity).relationships.size(), 0)
		root.free()
		_level = null
		await get_tree().process_frame
		assert_null(ECS.world, "Native level exit releases global World")
#endregion
