extends Node
## Isolated headless regression for real truck cargo blocking the Morning shift.


#region Smoke execution
func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var physical_root: Node3D = Node3D.new()
	add_child(physical_root)
	var world: World = World.new()
	physical_root.add_child(world)
	ECS.world = world

	var cycle: C_DayCycle = C_DayCycle.new()
	var session: Entity = Entity.new()
	session.component_resources = [cycle, C_PackageLedger.new()]
	world.add_entity(session)

	var zone_scene: PackedScene = load("res://content/entities/zones/receiving_zone.tscn") as PackedScene
	var zone: E_ReceivingZone = zone_scene.instantiate() as E_ReceivingZone
	zone.package_parent = physical_root
	var parking: Marker3D = Marker3D.new()
	physical_root.add_child(parking)
	zone.truck_parking = parking
	world.add_entity(zone)
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving

	# Exercise the existing physical receiving path without main_level or autosave.
	assert(not DayPhaseService.permits(cycle, DayTransitionRequest.Kind.START_SHIFT))
	var truck: E_MorningTruck = zone.ensure_truck()
	truck.door_animation.advance(1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	zone.supply = zone.supply.duplicate() as DEF_Delivery
	zone.supply.packages = [zone.supply.packages[1]]
	ReceivingDeliveryService.prepare_batch(zone.supply, receiving, cycle.day_index)
	ReceivingDeliveryService.deliver_one(zone, receiving, cycle.day_index)
	var packages: Array[Entity] = world.query.with_all([C_Package]).execute()
	assert(packages.size() == 1)
	var package_body: RigidBody3D = packages[0] as Node as RigidBody3D
	package_body.freeze = true
	assert(not DayPhaseService.permits(cycle, DayTransitionRequest.Kind.START_SHIFT))

	# Moving the same physical body out clears the gate; returning it restores it.
	package_body.global_position = parking.global_position + Vector3(8.0, 0.0, 0.0)
	await get_tree().physics_frame
	ReceivingDeliveryService.deliver_one(zone, receiving, cycle.day_index)
	assert(receiving.pending.is_empty())
	assert(DayPhaseService.permits(cycle, DayTransitionRequest.Kind.START_SHIFT))
	package_body.global_transform = truck.cargo_slots[0].global_transform
	assert(not DayPhaseService.permits(cycle, DayTransitionRequest.Kind.START_SHIFT))

	world.purge(false)
	physical_root.queue_free()
	ECS.world = null
	await get_tree().process_frame
	await get_tree().process_frame
	print("Truck shift gate smoke PASS")
	get_tree().quit()
#endregion
