extends Node


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
	(actor as Node as RigidBody3D).freeze = true
	var scanner: E_Scanner = level.get_node("Entityes/Scanner") as E_Scanner
	var first: Entity = level.get_node("Entityes/Parcel_001_01") as Entity
	var second: Entity = level.get_node("Entityes/Parcel_001_02") as Entity
	var ray: RayCast3D = S_Grab.interaction_raycast(actor)
	ray.look_at((scanner as Node as Node3D).global_position)
	_drive(actor, true, false, false)
	assert(S_Grab.held_object(actor) == scanner, "E must pick up the real scanner")
	ray.look_at((first as Node as Node3D).global_position + Vector3.UP * 0.2)
	_drive(actor, false, false, true)
	var first_state: C_PackageState = first.get_component(C_PackageState) as C_PackageState
	var registry: C_PackageLedger = PackageRegistrationService.ledger()
	assert(first_state.registration_number == "001-001" and registry.records.size() == 1)
	assert(first_state.scan == C_PackageState.Scan.SCANNED)
	assert(S_Grab.held_object(actor) == scanner, "Scan must not throw")
	var feedback: Label3D = scanner.get_node("Feedback/Result") as Label3D
	assert("001-001" in feedback.text)
	assert((scanner.get_node("Feedback/Beep") as AudioStreamPlayer3D).playing)
	_drive(actor, false, false, true)
	assert(first_state.registration_number == "001-001" and registry.records.size() == 1)
	assert("Уже учтена" in feedback.text)
	(actor as Node as Node3D).global_position = (
		(second as Node as Node3D).global_position + Vector3(0, 0.1, 1.8)
	)
	ray.look_at((second as Node as Node3D).global_position + Vector3.UP * 0.2)
	_drive(actor, false, false, true)
	var second_state: C_PackageState = second.get_component(C_PackageState) as C_PackageState
	assert(second_state.registration_number == "001-002" and registry.records.size() == 2)
	var scanner_config: C_Scanner = scanner.get_component(C_Scanner) as C_Scanner
	scanner_config.scan_range = 0.1
	assert(
		PackageRegistrationService.scan(actor, scanner, second).outcome
		== ScanResult.Outcome.REJECTED
	)
	scanner_config.scan_range = 3.0
	ray.look_at(ray.global_position + Vector3(0, 1, -1))
	assert(
		PackageRegistrationService.scan(actor, scanner, first).outcome
		== ScanResult.Outcome.REJECTED
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
	(actor as Node as Node3D).global_position = Vector3(2.1, 0.1, -3.5)
	ray.look_at((terminal as Node as Node3D).global_position + Vector3.UP * 0.55)
	_drive(actor, false, true, false)
	assert(terminal.panel.visible)
	assert("001-001" in terminal.panel.registry.text and "001-002" in terminal.panel.registry.text)
	assert(
		"Хрупкое" in terminal.panel.registry.text
		and "Опасное содержимое" in terminal.panel.registry.text
	)
	if OS.get_cmdline_user_args().has("--preview"):
		await RenderingServer.frame_post_draw
		var screenshot: Image = get_viewport().get_texture().get_image()
		assert(screenshot.save_png("res://tests/artifacts/terminal_preview.png") == OK)
	terminal.panel.close_panel()
	var previous_location: Vector3 = (first as Node as Node3D).global_position
	for parcel: Entity in parcels:
		(parcel as Node as RigidBody3D).freeze = true
	# Block the receiving footprint before the next Morning; no overlap spawning is allowed.
	var blocker: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(8, 1, 5)
	collision.shape = box_shape
	blocker.add_child(collision)
	blocker.position = Vector3(3.8, 0.5, -5.5)
	level.add_child(blocker)
	await get_tree().physics_frame
	for transition: DayTransitionRequest.Kind in [
		DayTransitionRequest.Kind.START_SHIFT,
		DayTransitionRequest.Kind.FINISH_SHIFT,
		DayTransitionRequest.Kind.SLEEP,
	]:
		var cycle: C_DayCycle = S_DayPhase.current()
		var request: DayTransitionRequest = DayTransitionRequest.new()
		request.kind = transition
		request.expected_day = cycle.day_index
		request.expected_phase = cycle.phase
		assert(S_DayPhase.submit(request))
		ECS.world.process(1.0 / 60.0, "GamePlay")
	ECS.world.process(1.0 / 60.0, "GamePlay")
	assert(S_DayPhase.current().day_index == 2)
	var zone: E_ReceivingZone = level.get_node("Entityes/ReceivingZone") as E_ReceivingZone
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	assert(receiving.blocked and ECS.world.query.with_all([C_Package]).execute().size() == 8)
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
	assert("001-001" not in PackageRegistrationService.terminal_text(2))
	var next_day_parcel: Entity = level.get_node("Entityes/Parcel_002_01") as Entity
	(actor as Node as Node3D).global_position = (
		(next_day_parcel as Node as Node3D).global_position + Vector3(0, 0.1, 1.8)
	)
	ray.look_at((next_day_parcel as Node as Node3D).global_position + Vector3.UP * 0.2)
	assert(PackageRegistrationService.scan(actor, scanner, next_day_parcel).number == "002-001")
	assert("002-001" in PackageRegistrationService.terminal_text(2))
	(actor as Node as Node3D).global_position = previous_location + Vector3(0, 0.1, 1.8)
	ray.look_at(previous_location + Vector3.UP * 0.2)
	assert(PackageRegistrationService.scan(actor, scanner, first).number == "001-001")
	assert(registry.records.size() == 3)
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
