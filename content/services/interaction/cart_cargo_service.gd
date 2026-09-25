extends RefCounted
## Owns cargo binding lifecycle and cart-local discovery. R_CartCargo is sole authority.
class_name CartCargoService

const SUPPORT_DISTANCE: float = 0.06
const MIN_SUPPORT_NORMAL: float = 0.7


static func relationship(cargo: Entity) -> Relationship:
	if not is_instance_valid(cargo):
		return null
	for candidate: Relationship in cargo.relationships:
		if candidate.relation is R_CartCargo:
			return candidate
	return null


static func update(cart: E_TransportCart, delta: float) -> void:
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if config == null:
		return

	for loaded: Entity in config.cargo.duplicate():
		var binding: Relationship = relationship(loaded)
		if binding == null or binding.target != cart or not S_Grab.entity_available(loaded):
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

		var elapsed: float = float(config.settling.get(instance_id, 0.0)) + delta
		config.settling[instance_id] = elapsed
		if elapsed >= config.cargo_settle_seconds:
			_load(cart, candidate, body)
			config.settling.erase(instance_id)

	for instance_id: int in config.settling.keys():
		if not present.has(instance_id):
			config.settling.erase(instance_id)


static func release(cargo: Entity) -> void:
	if not is_instance_valid(cargo):
		return
	var binding: Relationship = relationship(cargo)
	if binding == null:
		return
	cargo.remove_relationship(binding)
	cargo_removed(cargo, binding)


static func release_all(cart: Entity) -> void:
	if not is_instance_valid(cart):
		return
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if config == null:
		return
	for cargo: Entity in config.cargo.duplicate():
		var binding: Relationship = relationship(cargo)
		if binding != null and binding.target == cart:
			release(cargo)
	config.cargo.clear()
	config.settling.clear()


static func cargo_added(cargo: Entity, binding: Relationship) -> bool:
	var data: R_CartCargo = binding.relation as R_CartCargo
	var cart: Entity = binding.target as Entity
	if data == null or data.lifecycle_applied:
		return data != null
	if not S_Grab.entity_available(cargo) or not S_Grab.entity_available(cart):
		return false
	if relationship(cargo) != binding:
		return false

	var body: RigidBody3D = cargo as Node as RigidBody3D
	var cart_body: PhysicsBody3D = cart as Node as PhysicsBody3D
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if body == null or cart_body == null or config == null or body.freeze:
		return false

	data.previous_can_sleep = body.can_sleep
	data.previous_custom_integrator = body.custom_integrator
	data.added_exception = not body.get_collision_exceptions().has(cart_body)
	if data.added_exception:
		body.add_collision_exception_with(cart_body)

	body.custom_integrator = true
	body.can_sleep = false
	body.sleeping = false
	if not config.cargo.has(cargo):
		config.cargo.append(cargo)
	data.lifecycle_applied = true
	return true


static func cargo_removed(cargo: Entity, binding: Relationship) -> void:
	var data: R_CartCargo = binding.relation as R_CartCargo
	if data == null or not data.lifecycle_applied:
		return
	data.lifecycle_applied = false

	var cart: Entity = binding.target as Entity if is_instance_valid(binding.target) else null
	var body: RigidBody3D = cargo as Node as RigidBody3D if is_instance_valid(cargo) else null
	if body != null:
		body.custom_integrator = data.previous_custom_integrator
		body.can_sleep = data.previous_can_sleep
		if data.added_exception and is_instance_valid(cart):
			var cart_body: PhysicsBody3D = cart as Node as PhysicsBody3D
			if cart_body != null:
				body.remove_collision_exception_with(cart_body)

	if is_instance_valid(cart):
		var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
		if config != null:
			config.cargo.erase(cargo)


static func _loadable(cargo: Entity) -> bool:
	if not S_Grab.entity_available(cargo) or not cargo.has_component(C_Grabbable):
		return false
	if relationship(cargo) != null or S_Grab.held_relationship(cargo) != null:
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
	var binding: Relationship = relationship(support)
	return binding != null and binding.target == cart


static func _load(cart: Entity, cargo: Entity, body: RigidBody3D) -> void:
	if relationship(cargo) != null:
		return
	var cart_body: PhysicsBody3D = cart as Node as PhysicsBody3D
	if cart_body == null:
		return
	var data: R_CartCargo = R_CartCargo.new()
	data.local_pose = cart_body.global_transform.affine_inverse() * body.global_transform
	var binding: Relationship = Relationship.new(data, cart)
	cargo.add_relationship(binding)
	if not data.lifecycle_applied and not cargo_added(cargo, binding):
		cargo.remove_relationship(binding)
