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
	var damage: DamageRequest = DamageRequest.new()
	damage.target = parcel
	damage.amount = 10000.0
	S_Damage.submit(damage)
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


func _drive(actor: Entity, primary: bool, secondary: bool) -> void:
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	controller.input_tick += 1
	controller.action_main = primary
	controller.action_main_pressed = primary
	controller.action_second = secondary
	controller.action_second_held = secondary
	controller.action_second_pressed = secondary
	ECS.world.process(STEP, "Interaction")
