extends System
## Assists settled cargo in the cart's moving frame while keeping external collisions physical.
class_name S_CartCargo

const SUPPORT_DISTANCE: float = 0.06
const MIN_SUPPORT_NORMAL: float = 0.7
const MAX_ANGULAR_SPEED: float = 6.0
const ROTATION_EPSILON: float = 0.0001


#region Loading and lifecycle
## Called outside GECS iteration by the cart's physics callback after its movement.
static func update(cart: E_TransportCart, delta: float) -> void:
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	for loaded: Entity in config.cargo.duplicate():
		if not S_Grab.entity_available(loaded):
			release(loaded)
			config.cargo.erase(loaded)

	var present: Dictionary[int, bool] = { }
	for node: Node3D in cart.cargo_area.get_overlapping_bodies():
		var candidate: Entity = node as Node as Entity
		if not _loadable(candidate):
			continue
		var body: RigidBody3D = node as RigidBody3D
		var instance_id: int = candidate.get_instance_id()
		present[instance_id] = true
		var relative_speed: float = (body.linear_velocity - config.actual_velocity).length()
		if relative_speed > config.cargo_settle_speed or not _supported(body, cart):
			config.settling.erase(instance_id)
			continue

		var elapsed: float = config.settling.get(instance_id, 0.0) + delta
		config.settling[instance_id] = elapsed
		if elapsed >= config.cargo_settle_seconds:
			_load(cart, candidate, body)
			config.settling.erase(instance_id)

	for instance_id: int in config.settling.keys():
		if not present.has(instance_id):
			config.settling.erase(instance_id)


## Idempotently restores free-body policy; Grab can immediately take the same body.
static func release(cargo: Entity) -> void:
	if not is_instance_valid(cargo):
		return
	var binding: C_CartCargo = cargo.get_component(C_CartCargo) as C_CartCargo
	if binding == null:
		return
	var body: RigidBody3D = cargo as Node as RigidBody3D
	if body != null:
		body.custom_integrator = binding.previous_custom_integrator
		body.can_sleep = binding.previous_can_sleep
		if binding.added_exception and is_instance_valid(binding.cart):
			body.remove_collision_exception_with(binding.cart as Node as PhysicsBody3D)

	if is_instance_valid(binding.cart):
		var config: C_CartTransport = binding.cart.get_component(C_CartTransport) as C_CartTransport
		if config != null:
			config.cargo.erase(cargo)
	cargo.remove_component(C_CartCargo)


## Called when a cart leaves the World or its scene tree; no frozen orphan cargo remains.
static func release_all(cart: Entity) -> void:
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if config == null:
		return
	for cargo: Entity in config.cargo.duplicate():
		release(cargo)
	config.cargo.clear()
	config.settling.clear()
#endregion


#region Rigid-body solver
## Velocity-only restraint in the rigid body's own callback; never teleports/reparents cargo.
static func integrate(cargo: Entity, state: PhysicsDirectBodyState3D) -> bool:
	var binding: C_CartCargo = cargo.get_component(C_CartCargo) as C_CartCargo
	if binding == null:
		return false
	if not S_Grab.entity_available(binding.cart) or not S_Grab.entity_available(cargo):
		release(cargo)
		return false
	if S_Grab.held_relationship(cargo) != null or _destroyed(cargo):
		release(cargo)
		return false

	var cart_body: Node3D = binding.cart as Node as Node3D
	var config: C_CartTransport = binding.cart.get_component(C_CartTransport) as C_CartTransport
	var desired: Transform3D = cart_body.global_transform * binding.local_pose
	var offset: Vector3 = desired.origin - state.transform.origin
	if offset.length() > config.cargo_break_distance:
		release(cargo)
		return false

	state.linear_velocity = (offset / state.step).limit_length(config.cargo_follow_speed)
	var rotation_error: Quaternion = (
		desired.basis.get_rotation_quaternion()
		* state.transform.basis.get_rotation_quaternion().inverse()
	).normalized()
	if rotation_error.w < 0.0:
		rotation_error = -rotation_error
	var angle: float = rotation_error.get_angle()
	state.angular_velocity = Vector3.ZERO
	if angle > ROTATION_EPSILON:
		state.angular_velocity = rotation_error.get_axis() * minf(
			angle / state.step,
			MAX_ANGULAR_SPEED,
		)
	return true
#endregion


#region Private helpers
static func _loadable(cargo: Entity) -> bool:
	if not S_Grab.entity_available(cargo) or not cargo.has_component(C_Grabbable):
		return false
	if cargo.has_component(C_CartCargo) or S_Grab.held_relationship(cargo) != null:
		return false
	var body: RigidBody3D = cargo as Node as RigidBody3D
	return body != null and not body.freeze and not _destroyed(cargo)


static func _destroyed(cargo: Entity) -> bool:
	var package_state: C_PackageState = cargo.get_component(C_PackageState) as C_PackageState
	return package_state != null and package_state.damage == C_PackageState.Damage.DESTROYED


static func _supported(body: RigidBody3D, cart: Entity) -> bool:
	var contact: KinematicCollision3D = KinematicCollision3D.new()
	if not body.test_move(body.global_transform, Vector3.DOWN * SUPPORT_DISTANCE, contact):
		return false
	if contact.get_normal().y < MIN_SUPPORT_NORMAL:
		return false
	var support: Entity = contact.get_collider() as Node as Entity
	if support == cart:
		return true
	if not is_instance_valid(support):
		return false
	var binding: C_CartCargo = support.get_component(C_CartCargo) as C_CartCargo
	return binding != null and binding.cart == cart


static func _load(cart: Entity, cargo: Entity, body: RigidBody3D) -> void:
	var binding: C_CartCargo = C_CartCargo.new()
	var cart_body: PhysicsBody3D = cart as Node as PhysicsBody3D
	binding.cart = cart
	binding.local_pose = cart_body.global_transform.affine_inverse() * body.global_transform
	binding.previous_can_sleep = body.can_sleep
	binding.previous_custom_integrator = body.custom_integrator
	binding.added_exception = not body.get_collision_exceptions().has(cart_body)
	if binding.added_exception:
		body.add_collision_exception_with(cart_body)

	body.custom_integrator = true
	body.can_sleep = false
	body.sleeping = false
	cargo.add_component(binding)
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	config.cargo.append(cargo)
#endregion
