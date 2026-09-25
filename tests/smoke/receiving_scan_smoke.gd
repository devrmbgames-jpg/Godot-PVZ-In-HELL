extends Node
## End-to-end receiving, registration, number reuse and modal terminal regression.

var _prepared_body: Node3D = null
var _prepared_transform: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	var level: Node = scene.instantiate()
	add_child(level)
	for tick_index: int in 30:
		await get_tree().physics_frame
	var parcels: Array = ECS.world.query.with_all([C_Package]).execute()
	print("Receiving count: ", parcels.size())
	assert(parcels.size() == 8)
	var ids: Dictionary[String, bool] = { }
	var found_tags: int = 0
	var found_hazards: int = 0
	for parcel: Entity in parcels:
		var identity: C_Package = parcel.get_component(C_Package) as C_Package
		var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
		assert(not ids.has(identity.package_id))
		ids[identity.package_id] = true
		assert(
			identity.delivery_day == 1
			and state.registration == C_PackageState.Registration.UNREGISTERED
		)
		found_tags |= identity.definition.tags
		found_hazards |= 1 << identity.definition.hazard
	assert(found_tags == 15 and found_hazards == 7)
	for tick_index: int in 20:
		await get_tree().physics_frame
	assert(ECS.world.query.with_all([C_Package]).execute().size() == 8)
	level.set_physics_process(false)
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	(actor as Node as RigidBody3D).freeze = true
	var scanner: E_Scanner = level.get_node("Entityes/Scanner") as E_Scanner
	var first: Entity = level.get_node("Entityes/Parcel_001_01") as Entity
	var second: Entity = level.get_node("Entityes/Parcel_001_02") as Entity
	var first_supply_position: Vector3 = (first as Node as Node3D).global_position
	var second_supply_position: Vector3 = (second as Node as Node3D).global_position
	await _prepare_target(actor, scanner, Vector3(0.0, 0.0, -1.6))
	assert(GrabService.within_pickup_reach(actor, scanner))
	_drive(actor, true, false, false)
	assert(GrabService.held_object(actor) == scanner, "E must pick up the real scanner")
	await _prepare_target(actor, first, Vector3(0.0, -0.2, -2.2))
	assert(InteractionTargetingService.find_target(actor, interactor) == first)
	_drive(actor, false, false, true)
	var first_state: C_PackageState = first.get_component(C_PackageState) as C_PackageState
	var registry: C_PackageLedger = PackageRegistrationService.ledger()
	assert(first_state.registration_number == 1 and registry.records.size() == 1)
	assert(first_state.scan == C_PackageState.Scan.SCANNED)
	assert(GrabService.held_object(actor) == scanner, "Scan must not throw")
	var feedback: Label3D = scanner.get_node("Feedback/Result") as Label3D
	assert("\u2116001" in feedback.text)
	assert((scanner.get_node("Feedback/Beep") as AudioStreamPlayer3D).playing)
	_drive(actor, false, false, true)
	assert(first_state.registration_number == 1 and registry.records.size() == 1)
	assert("\u2116001" in feedback.text)
	await _prepare_target(actor, second, Vector3(0.0, -0.2, -2.2))
	assert(InteractionTargetingService.find_target(actor, interactor) == second)
	_drive(actor, false, false, true)
	var second_state: C_PackageState = second.get_component(C_PackageState) as C_PackageState
	assert(second_state.registration_number == 2 and registry.records.size() == 2)
	var scanner_config: C_Scanner = scanner.get_component(C_Scanner) as C_Scanner
	scanner_config.scan_range = 0.1
	assert(
		PackageRegistrationService.scan(actor, scanner, second).outcome
		== PackageScanResult.Outcome.REJECTED
	)
	scanner_config.scan_range = 3.0
	var ray: RayCast3D = GrabService.interaction_raycast(actor)
	ray.look_at(ray.global_position + Vector3(0, 1, -1))
	ray.force_raycast_update()
	assert(
		PackageRegistrationService.scan(actor, scanner, first).outcome
		== PackageScanResult.Outcome.REJECTED
	)
	assert(registry.records.size() == 2)
	var terminal: E_Terminal = level.get_node("Entityes/Terminal") as E_Terminal
	var terminal_body: StaticBody3D = terminal as Node as StaticBody3D
	var desk_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var desk_shape: BoxShape3D = BoxShape3D.new()
	desk_shape.size = Vector3(1.28, 1.08, 0.68)
	desk_query.shape = desk_shape
	desk_query.transform = terminal_body.global_transform
	desk_query.transform.origin += Vector3.UP * 0.55
	desk_query.exclude = [terminal_body.get_rid()]
	assert(terminal_body.get_world_3d().direct_space_state.intersect_shape(desk_query).is_empty())
	await _prepare_target(actor, terminal, Vector3(0.0, -0.5, -1.8))
	assert(InteractionTargetingService.find_target(actor, interactor) == terminal)
	_drive(actor, true, false, false)
	assert(terminal.panel.visible)
	assert(
		"\u2116001" in terminal.panel.registry.text and "\u2116002" in terminal.panel.registry.text
	)
	assert(
		"Хрупкое" in terminal.panel.registry.text
		and "Опасное содержимое" in terminal.panel.registry.text
	)
	if OS.get_cmdline_user_args().has("--preview"):
		await RenderingServer.frame_post_draw
		var screenshot: Image = get_viewport().get_texture().get_image()
		assert(screenshot.save_png("res://tests/artifacts/terminal_preview.png") == OK)
	terminal.panel.close_panel()
	var first_body: RigidBody3D = first as Node as RigidBody3D
	var second_body: RigidBody3D = second as Node as RigidBody3D
	first_body.global_position = first_supply_position
	second_body.global_position = second_supply_position
	first_body.linear_velocity = Vector3.ZERO
	second_body.linear_velocity = Vector3.ZERO
	first_body.angular_velocity = Vector3.ZERO
	second_body.angular_velocity = Vector3.ZERO
	await get_tree().physics_frame
	var previous_location: Vector3 = (first as Node as Node3D).global_position
	for parcel: Entity in parcels:
		(parcel as Node as RigidBody3D).freeze = true
	# Block every receiving marker: delivery may not skip to a free spawn point.
	var zone: E_ReceivingZone = level.get_node("Entityes/ReceivingZone") as E_ReceivingZone
	var blockers: Array[StaticBody3D] = []
	var spawn_points: Node = zone.get_node("SpawnPoints")
	for spawn_point: Node in spawn_points.get_children():
		var marker: Node3D = spawn_point as Node3D
		var blocker: StaticBody3D = StaticBody3D.new()
		var collision: CollisionShape3D = CollisionShape3D.new()
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = Vector3(0.9, 1.0, 0.9)
		collision.shape = box_shape
		blocker.add_child(collision)
		level.add_child(blocker)
		blocker.global_position = marker.global_position
		blockers.append(blocker)
	await get_tree().physics_frame
	for transition: DayTransitionRequest.Kind in [
		DayTransitionRequest.Kind.START_SHIFT,
		DayTransitionRequest.Kind.FINISH_SHIFT,
		DayTransitionRequest.Kind.SLEEP,
	]:
		var cycle: C_DayCycle = DayPhaseService.current()
		var request: DayTransitionRequest = DayTransitionRequest.new()
		request.kind = transition
		request.expected_day = cycle.day_index
		request.expected_phase = cycle.phase
		assert(DayPhaseService.submit(request))
		ECS.world.process(1.0 / 60.0, "GamePlay")
	ECS.world.process(1.0 / 60.0, "GamePlay")
	assert(DayPhaseService.current().day_index == 2)
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	assert(receiving.blocked and ECS.world.query.with_all([C_Package]).execute().size() == 8)
	for blocker: StaticBody3D in blockers:
		blocker.queue_free()
	# Simulate shelving yesterday's supply, leaving the first parcel untouched.
	for parcel_index: int in range(1, parcels.size()):
		var stored: RigidBody3D = parcels[parcel_index] as Node as RigidBody3D
		stored.global_position = Vector3(-10, 1, parcel_index * 2)
	for tick_index: int in 45:
		await get_tree().physics_frame
		ECS.world.process(1.0 / 60.0, "GamePlay")
	assert(ECS.world.query.with_all([C_Package]).execute().size() == 16)
	assert((first as Node as Node3D).global_position.is_equal_approx(previous_location))
	assert("\u2116001" in PackageRegistrationService.terminal_text())
	var next_day_parcel: Entity = level.get_node("Entityes/Parcel_002_01") as Entity
	await _prepare_target(actor, next_day_parcel, Vector3(0.0, -0.2, -2.2))
	assert(InteractionTargetingService.find_target(actor, interactor) == next_day_parcel)
	assert(PackageRegistrationService.scan(actor, scanner, next_day_parcel).number == 3)
	assert("\u2116003" in PackageRegistrationService.terminal_text())
	await _prepare_target(actor, first, Vector3(0.0, -0.2, -2.2))
	assert(InteractionTargetingService.find_target(actor, interactor) == first)
	assert(PackageRegistrationService.scan(actor, scanner, first).number == 1)
	assert(registry.records.size() == 3)
	assert(not PackageRegistrationService.release_number(first))
	first_state.registration = C_PackageState.Registration.DELIVERED
	assert(PackageRegistrationService.release_number(first))
	assert(not PackageRegistrationService.release_number(first))
	assert(PackageRegistrationService.smallest_free_number(registry) == 1)
	assert(registry.records[1].active and registry.records[1].number == 2)
	assert("\u2116001" in PackageRegistrationService.terminal_text())
	var replacement: Entity = level.get_node("Entityes/Parcel_002_02") as Entity
	await _prepare_target(actor, replacement, Vector3(0.0, -0.2, -2.2))
	assert(PackageRegistrationService.scan(actor, scanner, replacement).number == 1)
	assert(PackageRegistrationService.smallest_free_number(registry) == 4)
	level.free()
	ECS.world = null
	print("R05/R06 receiving -> scan -> terminal -> next day smoke PASS")
	get_tree().quit()


func _drive(actor: Entity, interact: bool, use: bool, primary: bool) -> void:
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	controller.input_tick += 1
	controller.interact_pressed = interact
	controller.use_pressed = use
	controller.action_main_pressed = primary
	ECS.world.process(1.0 / 60.0, "Interaction")


func _prepare_target(actor: Entity, target: Entity, target_offset: Vector3) -> void:
	if is_instance_valid(_prepared_body):
		var previous_entity: Entity = _prepared_body as Node as Entity
		if GrabService.held_relationship(previous_entity) == null:
			_prepared_body.global_transform = _prepared_transform

	var target_body: Node3D = target as Node as Node3D
	_prepared_body = target_body
	_prepared_transform = target_body.global_transform
	var ray: RayCast3D = GrabService.interaction_raycast(actor)
	target_body.global_position = ray.global_position + target_offset
	await get_tree().physics_frame
	ray.look_at(target_body.global_position)
	ray.force_raycast_update()
	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingService.find_target(actor, interactor)
