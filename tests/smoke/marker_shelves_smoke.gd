extends Node
## Real physics-ray regression for hand mapping, marker ink, occlusion and lifecycle.

const STEP: float = 1.0 / 60.0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	var level: Node = scene.instantiate()
	add_child(level)
	level.set_physics_process(false)
	for tick: int in 12:
		await get_tree().physics_frame
		ECS.world.process(STEP, "GamePlay")

	var actor: Entity = level.get_node("Entityes/Player") as Entity
	var actor_body: RigidBody3D = actor as Node as RigidBody3D
	actor_body.freeze = true
	actor_body.position = Vector3(20, 20, 20)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var ray: RayCast3D = S_Grab.interaction_raycast(actor)
	var marker_tool: Entity = level.get_node("Entityes/Marker") as Entity
	var scanner: Entity = level.get_node("Entityes/Scanner") as Entity
	var parcel: Entity = level.get_node("Entityes/Parcel_001_03") as Entity
	var parcel_body: RigidBody3D = parcel as Node as RigidBody3D
	parcel_body.freeze = true
	parcel_body.global_position = camera.global_position + Vector3(0, -0.2, -1.8)
	parcel_body.global_rotation = Vector3.ZERO
	ray.look_at(camera.global_position + Vector3(0, 0, -2))
	camera.look_at(camera.global_position + Vector3(0, 0, -2))

	(scanner as Node as RigidBody3D).global_position = camera.global_position + Vector3(
		0.3,
		0,
		-0.8,
	)
	(marker_tool as Node as RigidBody3D).global_position = camera.global_position + Vector3(
		-0.3,
		0,
		-0.8,
	)
	await get_tree().physics_frame
	ray.look_at((scanner as Node as Node3D).global_position)
	assert(S_Grab.try_pickup(actor, scanner, C_Grabbable.HoldSlot.RIGHT_HAND))
	ray.look_at((marker_tool as Node as Node3D).global_position)
	assert(S_Grab.try_pickup(actor, marker_tool, C_Grabbable.HoldSlot.LEFT_HAND))
	ray.look_at(camera.global_position + Vector3(0, 0, -2))
	_drive(actor, true, false)
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	assert(state.registration_number == 1, "Scan before drawing must register the package")
	(scanner.get_node("Feedback/Beep") as AudioStreamPlayer3D).stop()
	var registry_text: String = PackageRegistrationService.terminal_text()
	var marker: C_Marker = marker_tool.get_component(C_Marker) as C_Marker
	_drive(actor, false, true)
	assert(marker.capture_token != 0, "Left hand starts on RMB")
	var marks: C_PackageMarks = parcel.get_component(C_PackageMarks) as C_PackageMarks
	assert(marks.point_count == 1, "Mapped held input must paint a first-hit package")
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	controller.look_delta = Vector2(8, 0)
	_drive(actor, false, true)
	assert(marks.point_count == 2)
	controller.look_delta = Vector2.ZERO
	_drive(actor, false, false)
	assert(marker.stroke == null)
	_drive(actor, false, true)
	assert(marks.strokes.size() == 2, "Button release splits strokes")
	assert(not (actor.get_component(C_GrabControl) as C_GrabControl).rotation_active)

	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1, 1, 0.1)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = camera.global_position + Vector3(0, 0, -1.0)
	await get_tree().physics_frame
	var before_wall: int = marks.point_count
	_drive(actor, false, true)
	assert(marks.point_count == before_wall, "Drawing must not pass through a wall")
	assert(marker.stroke == null)
	controller.cancel_pressed = true
	_drive(actor, false, false)
	assert(marker.capture_token == 0)
	controller.cancel_pressed = false
	assert(
		not S_Marker.can_begin(actor, marker_tool, parcel),
		"A wall also blocks starting drawing",
	)
	wall.free()
	await get_tree().physics_frame

	var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
	control.swap_hand_controls = true
	_drive(actor, true, false)
	assert(marker.capture_token != 0, "Swapped left hand starts on LMB")
	var previous_normal: Vector3 = marker.stroke.normal
	parcel_body.rotation.y = PI * 0.5
	await get_tree().physics_frame
	_drive(actor, true, false)
	assert(
		absf(marker.stroke.normal.dot(previous_normal)) < 0.01,
		"A rotated box must accept ink on its side face",
	)
	parcel_body.rotation.y = 0.0
	await get_tree().physics_frame
	controller.interact_pressed = true
	_drive(actor, false, false)
	controller.interact_pressed = false
	assert(marker.capture_token == 0, "E exits without releasing or replacing the marker")
	assert(S_Grab.held_in_slot(actor, C_Grabbable.HoldSlot.LEFT_HAND) == marker_tool)
	control.swap_hand_controls = false
	S_Grab.release(actor, scanner)
	S_Grab.release(actor, marker_tool)
	ray.look_at((marker_tool as Node as Node3D).global_position)
	assert(S_Grab.try_pickup(actor, marker_tool, C_Grabbable.HoldSlot.RIGHT_HAND))
	ray.look_at(camera.global_position + Vector3(0, 0, -2))
	_drive(actor, true, false)
	assert(marker.capture_token != 0, "Right hand starts on LMB")
	_draw_seven(actor, marker, parcel_body, camera)
	var escape: InputEventKey = InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	var input_system: S_PlayerInput = level.get_node("World/Systems/Input/S_PlayerInput")
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	input_system.process([actor], [[controller]], STEP)
	assert(
		controller.cancel_pressed,
		"Esc must reach drawing cancellation instead of the level menu",
	)
	_drive(actor, false, false)
	assert(marker.capture_token == 0)
	controller.cancel_pressed = false
	_drive(actor, true, false)
	assert(marker.capture_token != 0, "Reentering after Escape must work")
	S_Grab.release(actor, marker_tool)
	_drive(actor, false, false)
	assert(marker.capture_token == 0, "Lost ownership cancels capture")
	assert(InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.HANDS)

	var saved_points: PackedVector3Array = marks.strokes[0].points.duplicate()
	parcel_body.rotate_y(0.5)
	assert(marks.strokes[0].points == saved_points)
	await get_tree().process_frame
	await get_tree().process_frame
	var view: MeshInstance3D = parcel_body.get_node("Marks") as MeshInstance3D
	assert(view.mesh != null, "Local ink must generate visible geometry")
	assert(view.get_parent() == parcel_body)
	var visual: MeshInstance3D = parcel_body.get_node("Box_C") as MeshInstance3D
	assert(
		marks.strokes[0].points[0].z > visual.mesh.get_aabb().end.z,
		"Front ink must sit outside the visible mesh, not inside its collider tolerance",
	)
	await _store_on_shelf(level, actor, parcel_body, marks, camera)
	assert(
		PackageRegistrationService.terminal_text() == registry_text,
		"Storage must not disclose shelf placement to Terminal",
	)

	var damage: DamageRequest = DamageRequest.new()
	damage.target = parcel
	damage.amount = 10000.0
	DamageRequestService.submit(damage)
	ECS.world.process(STEP, "GamePlay")
	assert(state.damage == C_PackageState.Damage.DESTROYED)
	assert(marks.point_count == 0 and marks.strokes.is_empty())
	await get_tree().process_frame
	await get_tree().process_frame
	assert(view.mesh == null, "Destruction clears the rendered ink")

	(scanner.get_node("Feedback/Beep") as AudioStreamPlayer3D).stop()
	await get_tree().process_frame
	level.free()
	ECS.world = null
	print("R07 marker/shelves smoke PASS")
	get_tree().quit()


func _draw_seven(actor: Entity, marker: C_Marker, parcel_body: Node3D, camera: Camera3D) -> void:
	_drive(actor, false, false)
	var corners: Array[Vector3] = [
		Vector3(-0.14, 0.3, 0.3),
		Vector3(0.14, 0.3, 0.3),
		Vector3(-0.05, 0.06, 0.3),
	]
	for segment: int in 2:
		for sample_index: int in 12:
			var point: Vector3 = corners[segment].lerp(corners[segment + 1], sample_index / 11.0)
			marker.pointer = camera.unproject_position(parcel_body.to_global(point))
			_drive(actor, true, false)


func _store_on_shelf(
	level: Node,
	actor: Entity,
	parcel_body: RigidBody3D,
	marks: C_PackageMarks,
	camera: Camera3D,
) -> void:
	var shelves: StaticBody3D = level.get_node("PVZ/NumberedShelves") as StaticBody3D
	for number: int in range(1, 7):
		var label: Label3D = shelves.get_node("Number%02d" % number) as Label3D
		assert(label.text == "%02d" % number)
	assert(shelves.get_node("MiddleBoardCollision") is CollisionShape3D)

	(actor as Node as Node3D).global_position = shelves.global_position + Vector3(0, 0, 2)
	parcel_body.global_position = shelves.global_position + Vector3(0, 1.13, 0)
	parcel_body.global_rotation = Vector3(0, 0.15, 0)
	parcel_body.freeze = false
	parcel_body.linear_velocity = Vector3.ZERO
	parcel_body.angular_velocity = Vector3.ZERO
	var ray: RayCast3D = S_Grab.interaction_raycast(actor)
	ray.look_at(parcel_body.global_position + Vector3(0, 0.2, 0))
	await get_tree().physics_frame
	var parcel: Entity = parcel_body as Node as Entity
	assert(S_Grab.try_pickup(actor, parcel, C_Grabbable.HoldSlot.CARRY))
	var point_count: int = marks.point_count
	S_Grab.release(actor, parcel)
	for tick: int in 90:
		await get_tree().physics_frame

	var stored_position: Vector3 = shelves.to_local(parcel_body.global_position)
	assert(absf(stored_position.x) < 0.2)
	assert(
		stored_position.y > 1.0 and stored_position.y < 1.1,
		"The physical shelf must support the released parcel",
	)
	assert(absf(stored_position.z) < 0.2)
	assert(marks.point_count == point_count and point_count > 12)
	assert(parcel_body.linear_velocity.length() < 0.1)

	if "--preview" in OS.get_cmdline_user_args():
		(level.get_node("InteractionHud") as CanvasLayer).visible = false
		(actor as Node as Node3D).visible = false
		camera.global_position = shelves.global_position + Vector3(2.3, 2.2, 4.2)
		camera.look_at(shelves.global_position + Vector3(0, 1.0, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"res://tests/artifacts/r07_shelves_preview.png"
		)
		camera.global_position = shelves.global_position + Vector3(0.15, 1.6, 1.6)
		camera.look_at(parcel_body.global_position + Vector3(0, 0.2, 0))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"res://tests/artifacts/r07_marks_preview.png"
		)


func _drive(actor: Entity, primary: bool, secondary: bool) -> void:
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	controller.input_tick += 1
	controller.action_main = primary
	controller.action_main_pressed = primary
	controller.action_second = secondary
	controller.action_second_held = secondary
	controller.action_second_pressed = secondary
	ECS.world.process(STEP, "Interaction")
