extends RefCounted
## CharacterBody cart drive/terrain solver. Runs only from E_TransportCart._physics_process.
class_name CartDriveSolver

const MOTION_EPSILON: float = 0.0001
const COLLISION_MARGIN: float = 0.002
const MAX_TURN_CONTACTS: int = 8
const TERRAIN_MASK: int = 1


static func step(cart: E_TransportCart, delta: float) -> void:
	if not S_Grab.entity_available(cart) or delta <= 0.0:
		CartCargoService.release_all(cart)
		CartTransportService.end(cart)
		return
	var body: CharacterBody3D = cart as Node as CharacterBody3D
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if body == null or config == null:
		return

	var input_axis: Vector2 = Vector2.ZERO
	var binding: Relationship = CartTransportService.relationship(cart)
	if binding != null:
		var actor: Entity = binding.target as Entity
		var data: R_CartDrivenBy = binding.relation as R_CartDrivenBy
		var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(actor)
		if not CartTransportService.driver_valid(body, config, actor):
			CartTransportService.end(cart)
		elif (
			data != null and data.capture_token != 0
			and focus == InteractionControlFocus.Priority.TRANSPORT
		):
			var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
			input_axis = controller.move_axis
		else:
			config.drive_speed = 0.0

	var speed_limit: float = config.forward_speed if input_axis.y < 0.0 else config.reverse_speed
	var desired_speed: float = -input_axis.y * speed_limit
	config.drive_speed = move_toward(config.drive_speed, desired_speed, config.acceleration * delta)

	binding = CartTransportService.relationship(cart)
	if binding != null:
		var actor: Entity = binding.target as Entity
		if _driver_lag(body, config, actor) > config.follow_tolerance:
			var actor_node: Node3D = actor as Node as Node3D
			var separation: Vector3 = (
				CartTransportService.handle_position(body, config) - actor_node.global_position
			)
			var requested_motion: Vector3 = -body.global_basis.z * config.drive_speed
			if separation.dot(requested_motion) > 0.0:
				config.drive_speed = 0.0
			input_axis.x = 0.0

	var previous_position: Vector3 = body.global_position
	_turn(body, -input_axis.x * config.turn_speed * delta)
	var planar_velocity: Vector3 = -body.global_basis.z * config.drive_speed
	body.velocity = Vector3(planar_velocity.x, body.velocity.y, planar_velocity.z)
	body.floor_snap_length = config.floor_snap
	if body.is_on_floor():
		body.velocity.y = -config.gravity * delta
	else:
		body.velocity.y -= config.gravity * delta
	if not _try_step(body, planar_velocity * delta, config.step_height):
		body.move_and_slide()
	config.actual_velocity = (body.global_position - previous_position) / delta
	CartCargoService.update(cart, delta)


static func _driver_lag(
	body: CharacterBody3D,
	config: C_CartTransport,
	actor: Entity,
) -> float:
	var actor_node: Node3D = actor as Node as Node3D
	if actor_node == null:
		return 0.0
	var offset: Vector3 = (
		CartTransportService.handle_position(body, config) - actor_node.global_position
	)
	offset.y = 0.0
	return offset.length()


static func _turn(body: CharacterBody3D, angle: float) -> void:
	if absf(angle) < MOTION_EPSILON:
		return
	var proposed: Transform3D = body.global_transform
	proposed.basis = Basis(Vector3.UP, angle) * proposed.basis
	var collision: KinematicCollision3D = KinematicCollision3D.new()
	if body.test_move(proposed, Vector3.ZERO, collision, COLLISION_MARGIN, true, MAX_TURN_CONTACTS):
		for index: int in collision.get_collision_count():
			if collision.get_normal(index).dot(Vector3.UP) < cos(body.floor_max_angle):
				return
	body.global_transform = proposed


static func _try_step(body: CharacterBody3D, motion: Vector3, height: float) -> bool:
	if not body.is_on_floor() or motion.length_squared() < MOTION_EPSILON or height <= 0.0:
		return false
	var obstruction: KinematicCollision3D = KinematicCollision3D.new()
	if not body.test_move(body.global_transform, motion, obstruction):
		return false
	if obstruction.get_normal().dot(Vector3.UP) >= cos(body.floor_max_angle):
		return false
	var probe: Vector3 = obstruction.get_position() + motion.normalized() * height
	probe.y += height
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		probe,
		probe - Vector3.UP * height * 2.0,
		TERRAIN_MASK,
	)
	ray.exclude = [body.get_rid()]
	var support: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
	if support.is_empty():
		return false
	var support_normal: Vector3 = support["normal"] as Vector3
	if support_normal.y < cos(body.floor_max_angle):
		return false

	var raised: Transform3D = body.global_transform
	var up: Vector3 = Vector3.UP * height
	if body.test_move(raised, up):
		return false
	raised.origin += up
	if body.test_move(raised, motion):
		return false
	raised.origin += motion
	var landing: KinematicCollision3D = KinematicCollision3D.new()
	var down: Vector3 = Vector3.DOWN * (height + body.floor_snap_length)
	if not body.test_move(raised, down, landing):
		return false
	if landing.get_normal().y <= MOTION_EPSILON:
		return false

	body.move_and_collide(up)
	body.move_and_collide(motion)
	body.move_and_collide(down)
	body.velocity.y = 0.0
	body.apply_floor_snap()
	return true
