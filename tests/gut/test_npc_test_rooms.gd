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


#region All authored isolated rooms
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
				var receipt: PackageScanResult = PackageRegistrationService.register_package(parcel)
				assert_eq(receipt.outcome, PackageScanResult.Outcome.REGISTERED)
				var visit: CustomerVisit = CustomerFlowQueries.find_visit(
					StringName("visit/" + identity.package_id)
				)
				assert_not_null(visit)
				if visit == null:
					continue
				assert_eq(visit.customer_id, district.people[0].npc_id)
				assert_eq(visit.arrival_day, day)
				assert_true(CustomerFlowQueries.arrival_allowed(visit))
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
