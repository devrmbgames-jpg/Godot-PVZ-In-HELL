extends System
## Grounded cart transport and driver following; never changes generic S_Push behavior.
class_name S_CartTransport

const MOTION_EPSILON: float = 0.0001
const COLLISION_MARGIN: float = 0.002
const MAX_TURN_CONTACTS: int = 8
const TERRAIN_MASK: int = 1


#region Session API
## Validates live participants, reach, free transport ownership and unobstructed targeting.
static func can_begin(actor: Entity, cart: Entity) -> bool:
	if not S_Grab.holder_available(actor) or not S_Grab.entity_available(cart):
		return false
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if config == null or is_instance_valid(config.driver) or current(actor) != null:
		return false
	if not actor.has_component(C_Controller) or not actor.has_component(C_GrabControl):
		return false
	if InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PUSH:
		return false

	return S_Grab.within_pickup_reach(actor, cart)


## Acquires one transport token without changing either hand or Carry ownership.
static func begin(actor: Entity, cart: Entity) -> void:
	if not can_begin(actor, cart):
		return

	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	var driver_state: C_CartDriver = actor.get_component(C_CartDriver) as C_CartDriver
	if driver_state == null:
		driver_state = C_CartDriver.new()
		actor.add_component(driver_state)

	driver_state.cart = cart
	config.driver = actor
	config.capture_token = InteractionControlFocus.acquire(
		actor,
		cart,
		InteractionControlFocus.Priority.TRANSPORT,
	)
	var cleanup: Callable = _on_driver_exiting.bind(cart)
	if not actor.tree_exiting.is_connected(cleanup):
		actor.tree_exiting.connect(cleanup)


## Releases only this cart's capture and brakes; safe on repeated lifecycle cleanup.
static func end(cart: Entity) -> void:
	if not is_instance_valid(cart):
		return
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if config == null:
		return

	var actor: Entity = config.driver
	if is_instance_valid(actor):
		InteractionControlFocus.release(actor, config.capture_token)
		var driver_state: C_CartDriver = actor.get_component(C_CartDriver) as C_CartDriver
		if driver_state != null and driver_state.cart == cart:
			driver_state.cart = null
		var cleanup: Callable = _on_driver_exiting.bind(cart)
		if actor.tree_exiting.is_connected(cleanup):
			actor.tree_exiting.disconnect(cleanup)

	config.driver = null
	config.capture_token = 0
	config.drive_speed = 0.0


## Returns the live transport binding rather than a stale actor cache.
static func current(actor: Entity) -> Entity:
	if not is_instance_valid(actor):
		return null
	var driver_state: C_CartDriver = actor.get_component(C_CartDriver) as C_CartDriver
	if driver_state == null or not S_Grab.entity_available(driver_state.cart):
		return null
	var config: C_CartTransport = driver_state.cart.get_component(C_CartTransport)
	return driver_state.cart if config != null and config.driver == actor else null
#endregion


#region Physics
## CharacterBody owns movement: floor snap, slope sliding and tested small-step traversal.
static func step(cart: Entity, delta: float) -> void:
	if not S_Grab.entity_available(cart) or delta <= 0.0:
		S_CartCargo.release_all(cart)
		end(cart)
		return
	var body: CharacterBody3D = cart as Node as CharacterBody3D
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if body == null or config == null:
		return

	var input_axis: Vector2 = Vector2.ZERO
	if config.capture_token != 0:
		var focus: InteractionControlFocus.Priority = InteractionControlFocus.current(config.driver)
		if not _driver_valid(body, config):
			end(cart)
		elif focus == InteractionControlFocus.Priority.TRANSPORT:
			var controller: C_Controller = config.driver.get_component(C_Controller) as C_Controller
			input_axis = controller.move_axis
		else:
			config.drive_speed = 0.0

	var speed_limit: float = config.forward_speed if input_axis.y < 0.0 else config.reverse_speed
	var desired_speed: float = -input_axis.y * speed_limit
	config.drive_speed = move_toward(config.drive_speed, desired_speed, config.acceleration * delta)
	if _driver_lag(body, config) > config.follow_tolerance:
		var separation: Vector3 = _handle_position(body, config) - (
			config.driver as Node as Node3D
		).global_position
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
	S_CartCargo.update(cart as E_TransportCart, delta)


## Follows the handle with bounded rigid-body velocity; collisions still own actor motion.
static func integrate_actor(actor: Entity, state: PhysicsDirectBodyState3D) -> bool:
	var cart: Entity = current(actor)
	if (
		cart == null
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.TRANSPORT
	):
		return false
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	var body: CharacterBody3D = cart as Node as CharacterBody3D
	if not _driver_valid(body, config):
		end(cart)
		return false

	var correction: Vector3 = _handle_position(body, config) - state.transform.origin
	correction.y = 0.0
	var velocity: Vector3 = (
		correction / maxf(state.step, MOTION_EPSILON)
	).limit_length(config.follow_speed)
	state.linear_velocity = Vector3(velocity.x, minf(state.linear_velocity.y, 0.0), velocity.z)
	_lift_driver(actor, body, config, state)
	return true
#endregion


#region Collision helpers
static func _on_driver_exiting(cart: Entity) -> void:
	end(cart)


static func _lift_driver(
	actor: Entity,
	body: CharacterBody3D,
	config: C_CartTransport,
	state: PhysicsDirectBodyState3D,
) -> void:
	var handle: Vector3 = _handle_position(body, config)
	handle.y = state.transform.origin.y + config.step_height + COLLISION_MARGIN
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		handle,
		handle - Vector3.UP * (config.step_height * 2.0),
		TERRAIN_MASK,
	)
	ray.exclude = [(actor as Node as CollisionObject3D).get_rid(), body.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return
	var floor_normal: Vector3 = hit["normal"] as Vector3
	var floor_point: Vector3 = hit["position"] as Vector3
	var rise: float = floor_point.y - state.transform.origin.y
	if floor_normal.y < cos(body.floor_max_angle) or rise <= COLLISION_MARGIN:
		return
	if rise > config.step_height:
		return

	state.linear_velocity.y = maxf(
		state.linear_velocity.y,
		minf(rise / state.step, config.follow_speed),
	)


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


static func _driver_valid(body: CharacterBody3D, config: C_CartTransport) -> bool:
	if not S_Grab.holder_available(config.driver):
		return false
	var driver_position: Vector3 = (config.driver as Node as Node3D).global_position
	return body.global_position.distance_to(driver_position) <= config.focus_distance


static func _driver_lag(body: CharacterBody3D, config: C_CartTransport) -> float:
	if not is_instance_valid(config.driver):
		return 0.0
	var offset: Vector3 = _handle_position(body, config) - (
		config.driver as Node as Node3D
	).global_position
	offset.y = 0.0
	return offset.length()


static func _handle_position(body: CharacterBody3D, config: C_CartTransport) -> Vector3:
	return body.global_position + body.global_basis.z * config.handle_distance
#endregion
