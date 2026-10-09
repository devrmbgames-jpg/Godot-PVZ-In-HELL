extends Node
## Checks actual receiving, scanner/terminal state, blocked cargo and stable registration numbers.

## Isolated slot for the real Night transition; live user slots remain outside this fixture.
const SAVE_PATH: String = "user://receiving_scan_smoke.pvzh"
## Bounds real physics/phase waits instead of relying on an arbitrary elapsed delay.
const MAX_FRAMES: int = 480
## Gives large box shapes clearance from the conservative native truck cargo volume.
const UNLOAD_CLEARANCE_METERS: float = 4.0

var _prepared_body: Node3D = null
var _prepared_transform: Transform3D = Transform3D.IDENTITY


#region Actual receiving and registration
func _ready() -> void:
	_run.call_deferred()


## Exercises current authored supply and the real scanner/terminal across two mornings.
func _run() -> void:
	_cleanup_slot()
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	var level: Node = scene.instantiate()
	level.set("autosave_path", SAVE_PATH)
	add_child(level)
	level.set_physics_process(false)
	var actor: Entity = level.get_node("Entityes/Player") as Entity
	(actor as Node).set_physics_process(false)
	var feedback_nodes: Array[Node] = level.find_children("CharacterFeedback", "CharacterFeedback")
	for node: Node in feedback_nodes:
		(node as CharacterFeedback).footsteps_enabled = false
	var zone: E_ReceivingZone = level.get_node("Entityes/ReceivingZone") as E_ReceivingZone
	var batch_size: int = mini(zone.supply.maximum_batch_packages, zone.supply.packages.size())
	assert(batch_size >= 2)
	for frame: int in MAX_FRAMES:
		await get_tree().physics_frame
		GameTimeFixture.gameplay(ECS.world, 1.0 / 60.0)
		if ECS.world.query.with_all([C_Package]).execute().size() == batch_size:
			break

	var parcels: Array[Entity] = []
	parcels.assign(ECS.world.query.with_all([C_Package]).execute())
	print("Receiving count: ", parcels.size())
	assert(parcels.size() == batch_size)
	# Model actual unloading to warehouse markers before the normal START_SHIFT gate.
	for index: int in parcels.size():
		var body: RigidBody3D = parcels[index] as Node as RigidBody3D
		var marker: Node3D = zone.get_spawn_points().get_child(index) as Node3D
		body.global_transform = marker.global_transform
		body.global_position += zone.truck_parking.global_basis.x * UNLOAD_CLEARANCE_METERS
		assert(not zone.get_truck().overlaps_cargo(body))
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.require_finished_customers = false
	cycle.require_empty_customer_room = false
	cycle.require_all_planned_arrivals = false
	cycle.minimum_shift_seconds = 0.0
	var ids: Dictionary[String, bool] = { }
	var found_tags: int = 0
	var found_damage_hazard: bool = false
	var found_destroyed_hazard: bool = false
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
		found_damage_hazard = (
			found_damage_hazard or identity.definition.hazard_on_damaged != null
		)
		found_destroyed_hazard = (
			found_destroyed_hazard or identity.definition.hazard_on_destroyed != null
		)
	assert(found_tags == 15 and found_damage_hazard and found_destroyed_hazard)
	for tick_index: int in 20:
		await get_tree().physics_frame
	assert(ECS.world.query.with_all([C_Package]).execute().size() == batch_size)

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	assert((actor as Node) is CharacterBody3D)
	var scanner: E_Scanner = level.get_node("Entityes/Scanner") as E_Scanner
	var first: Entity = level.get_node("Entityes/Parcel_001_01") as Entity
	var second: Entity = level.get_node("Entityes/Parcel_001_02") as Entity
	var first_supply_position: Vector3 = (first as Node as Node3D).global_position
	var second_supply_position: Vector3 = (second as Node as Node3D).global_position
	await _prepare_target(actor, scanner, Vector3(0.0, 0.0, -1.6))
	assert(GrabReachQueries.within_pickup_reach(actor, scanner))
	_drive(actor, true, false, false)
	assert(GrabQueries.held_object(actor) == scanner, "E must pick up the real scanner")
	await _prepare_target(actor, first, Vector3(0.0, -0.2, -2.2))
	assert(InteractionTargetingGeometry.find_target(actor, interactor) == first)
	_drive(actor, false, false, true)

	var first_state: C_PackageState = first.get_component(C_PackageState) as C_PackageState
	var registry: C_PackageLedger = PackageQueries.ledger()
	assert(first_state.registration_number == 1 and _registered_count(registry) == 1)
	assert(first_state.scan == C_PackageState.Scan.SCANNED)
	assert(GrabQueries.held_object(actor) == scanner, "Scan must not throw")
	var feedback: Label3D = scanner.get_node("Feedback/Result") as Label3D
	assert("\u2116001" in feedback.text)
	assert((scanner.get_node("Feedback/Beep") as AudioStreamPlayer3D).playing)
	_drive(actor, false, false, true)
	assert(first_state.registration_number == 1 and _registered_count(registry) == 1)
	assert("\u2116001" in feedback.text)
	await _prepare_target(actor, second, Vector3(0.0, -0.2, -2.2))
	assert(InteractionTargetingGeometry.find_target(actor, interactor) == second)
	_drive(actor, false, false, true)

	var second_state: C_PackageState = second.get_component(C_PackageState) as C_PackageState
	assert(second_state.registration_number == 2 and _registered_count(registry) == 2)
	var scanner_config: C_Scanner = scanner.get_component(C_Scanner) as C_Scanner
	scanner_config.scan_range = 0.1
	assert(
		PackageRegistrationService.scan(actor, scanner, second).outcome
		== PackageScanResult.Outcome.REJECTED
	)
	scanner_config.scan_range = 3.0

	var ray: RayCast3D = GrabQueries.interaction_raycast(actor)
	ray.look_at(ray.global_position + Vector3(0, 1, -1))
	ray.force_raycast_update()
	assert(
		PackageRegistrationService.scan(actor, scanner, first).outcome
		== PackageScanResult.Outcome.REJECTED
	)
	assert(_registered_count(registry) == 2)

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
	assert(InteractionTargetingGeometry.find_target(actor, interactor) == terminal)
	_drive(actor, true, false, false)
	assert(terminal.is_panel_open())

	var terminal_panel: TerminalPanel = terminal.get_node("TerminalPanel") as TerminalPanel
	var package_list: VBoxContainer = terminal_panel.get_node("%PackageList") as VBoxContainer
	assert(package_list.get_child_count() == batch_size)
	var found_number_one: bool = false
	var found_number_two: bool = false
	var found_fragile: bool = false
	var found_hazard: bool = false
	for child: Node in package_list.get_children():
		var package_line: UI_TerminalButtonPackage = child as UI_TerminalButtonPackage
		assert(package_line != null)
		var number_label: Label = package_line.get_node("%LabelNumber") as Label
		found_number_one = found_number_one or number_label.text == "№001"
		found_number_two = found_number_two or number_label.text == "№002"
		found_fragile = found_fragile or (package_line.get_node("%IconFragile") as Control).visible
		found_hazard = found_hazard or (package_line.get_node("%IconAnomaly") as Control).visible
	assert(found_number_one and found_number_two)
	assert(found_fragile and found_hazard)
	if OS.get_cmdline_user_args().has("--preview"):
		await RenderingServer.frame_post_draw
		var screenshot: Image = get_viewport().get_texture().get_image()
		assert(screenshot.save_png("res://tests/artifacts/terminal_preview.png") == OK)
	terminal.close_panel()

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
	await _transition(DayTransitionRequest.Kind.START_SHIFT)
	await _transition(DayTransitionRequest.Kind.FINISH_SHIFT)
	for frame: int in MAX_FRAMES:
		await get_tree().physics_frame
		if zone.get_truck() == null:
			break
	assert(zone.get_truck() == null)
	await _transition(DayTransitionRequest.Kind.SLEEP)
	assert(DayPhaseQueries.current().day_index == 2)
	for parcel: Entity in parcels:
		(parcel as Node as RigidBody3D).freeze = true
	# Block every actual cargo candidate before the new truck can accept its first parcel.
	var blockers: Array[StaticBody3D] = []
	var incoming_truck: E_MorningTruck = zone.ensure_truck()
	assert(incoming_truck != null)
	for marker: Marker3D in zone.get_cargo_markers():
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
	GameTimeFixture.gameplay(ECS.world, 1.0 / 60.0)
	var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
	assert(receiving.blocked
		and ECS.world.query.with_all([C_Package]).execute().size() == batch_size)
	for blocker: StaticBody3D in blockers:
		blocker.queue_free()
	# Тест убирает вчерашнюю поставку на полки, оставляя первую коробку на месте.
	for parcel_index: int in range(1, parcels.size()):
		var stored: RigidBody3D = parcels[parcel_index] as Node as RigidBody3D
		stored.global_position = Vector3(-10, 1, parcel_index * 2)
	for frame: int in MAX_FRAMES:
		await get_tree().physics_frame
		GameTimeFixture.gameplay(ECS.world, 1.0 / 60.0)
		if ECS.world.query.with_all([C_Package]).execute().size() == batch_size * 2:
			break
	assert(ECS.world.query.with_all([C_Package]).execute().size() == batch_size * 2)
	assert((first as Node as Node3D).global_position.is_equal_approx(previous_location))
	assert(_has_active_number(registry, 1))

	# The real Night reset releases held objects; acquire the same scanner through input again.
	assert(GrabQueries.held_object(actor) == null)
	await _prepare_target(actor, scanner, Vector3(0.0, 0.0, -1.6))
	_drive(actor, true, false, false)
	assert(GrabQueries.held_object(actor) == scanner)

	var next_day_parcel: Entity = level.get_node("Entityes/Parcel_002_01") as Entity
	await _prepare_target(actor, next_day_parcel, Vector3(0.0, -0.2, -2.2))
	assert(InteractionTargetingGeometry.find_target(actor, interactor) == next_day_parcel)
	assert(PackageRegistrationService.scan(actor, scanner, next_day_parcel).number == 3)
	assert(_has_active_number(registry, 3))
	await _prepare_target(actor, first, Vector3(0.0, -0.2, -2.2))
	assert(InteractionTargetingGeometry.find_target(actor, interactor) == first)
	assert(PackageRegistrationService.scan(actor, scanner, first).number == 1)
	assert(_registered_count(registry) == 3)
	assert(registry.records.size() == batch_size * 2)
	assert(not PackageRegistrationService.release_number(first))
	first_state.registration = C_PackageState.Registration.DELIVERED
	assert(PackageRegistrationService.release_number(first))
	assert(not PackageRegistrationService.release_number(first))
	assert(PackageRegistrationService.smallest_free_number(registry) == 1)
	assert(_has_active_number(registry, 2))
	assert(registry.last_departed_package_id == (first.get_component(C_Package) as C_Package).package_id)

	var replacement: Entity = level.get_node("Entityes/Parcel_002_02") as Entity
	await _prepare_target(actor, replacement, Vector3(0.0, -0.2, -2.2))
	assert(PackageRegistrationService.scan(actor, scanner, replacement).number == 1)
	assert(PackageRegistrationService.smallest_free_number(registry) == 4)
	level.free()
	ECS.world = null
	await get_tree().process_frame
	_cleanup_slot()
	print("R05/R06 receiving -> scan -> terminal -> next day smoke PASS")
	get_tree().quit()


#endregion

#region Тестовый ввод и наведение
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
		if GrabQueries.held_relationship(previous_entity) == null:
			_prepared_body.global_transform = _prepared_transform

	var target_body: Node3D = target as Node as Node3D
	_prepared_body = target_body
	_prepared_transform = target_body.global_transform
	var ray: RayCast3D = GrabQueries.interaction_raycast(actor)
	target_body.global_position = ray.global_position + target_offset
	await get_tree().physics_frame
	ray.look_at(target_body.global_position)
	ray.force_raycast_update()

	var interactor: C_Interactor = actor.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingGeometry.find_target(actor, interactor)


func _has_active_number(registry: C_PackageLedger, number: int) -> bool:
	for record: PackageRegistrationRecord in registry.records:
		if record.active and record.number == number:
			return true
	return false

#endregion


#region Fixture transition and receipt contracts
func _transition(kind: DayTransitionRequest.Kind) -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var initial_day: int = cycle.day_index
	var initial_phase: C_DayCycle.Phase = cycle.phase
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = kind
	request.expected_day = initial_day
	request.expected_phase = initial_phase
	var submitted: bool = DayPhaseService.submit(request)
	assert(submitted, "kind=%s; start=%s; finish=%s; sleep=%s"
		% [kind, DayPhaseService.start_blockers(cycle), DayPhaseService.finish_blockers(cycle),
			NpcSleepService.blockers()])
	for frame: int in MAX_FRAMES:
		GameTimeFixture.gameplay(ECS.world, 1.0 / 60.0)
		if cycle.phase != initial_phase and cycle.phase != C_DayCycle.Phase.NIGHT:
			return
		await get_tree().physics_frame
	assert(false, "Day transition did not complete within the fixture frame bound")


func _registered_count(registry: C_PackageLedger) -> int:
	var count: int = 0
	for receipt: PackageRegistrationRecord in registry.records:
		if receipt.active and receipt.number > 0:
			count += 1
	return count


func _cleanup_slot() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
#endregion
