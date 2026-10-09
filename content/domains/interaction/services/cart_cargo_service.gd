extends RefCounted
## Explicit cargo bind/release/lookup and reversible R_CartCargo lifecycle effects; no membership clock.
class_name CartCargoService


#region Обнаружение и освобождение груза
## Освобождает связь конкретного груза и её физические эффекты.
static func release(cargo: Entity) -> void:
	if not is_instance_valid(cargo):
		return

	var binding: Relationship = CartCargoQueries.relationship(cargo)
	if binding == null:
		return

	cargo.remove_relationship(binding)
	cargo_removed(cargo, binding)


## Освобождает принадлежащий тележке груз и сбрасывает таймеры кандидатов.
static func release_all(cart: Entity) -> void:
	if not is_instance_valid(cart):
		return

	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if config == null:
		return

	for cargo: Entity in config.cargo.duplicate():
		var binding: Relationship = CartCargoQueries.relationship(cargo)
		if binding != null and binding.target == cart:
			release(cargo)
	config.cargo.clear()
	config.settling.clear()


#endregion

#region Эффекты связи груза
## Однократно включает custom_integrator, исключение столкновений и производный кеш груза.
static func cargo_added(cargo: Entity, binding: Relationship) -> bool:
	var data: R_CartCargo = binding.relation as R_CartCargo
	var cart: Entity = binding.target as Entity
	if data == null or data.lifecycle_applied:
		return data != null
	if not GrabQueries.entity_available(cargo) or not GrabQueries.entity_available(cart):
		return false
	if CartCargoQueries.relationship(cargo) != binding:
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


## Однократно возвращает исходный integrator/сон/столкновения и очищает кеш тележки.
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


#endregion

#region Физическая допустимость и загрузка
## Checks explicit live cargo eligibility without any settling progression.
static func loadable(cargo: Entity) -> bool:
	if not GrabQueries.entity_available(cargo) or not cargo.has_component(C_Grabbable):
		return false
	if CartCargoQueries.relationship(cargo) != null or GrabQueries.held_relationship(cargo) != null:
		return false

	var body: RigidBody3D = cargo as Node as RigidBody3D
	return body != null and not body.freeze and not _destroyed(cargo)


static func _destroyed(cargo: Entity) -> bool:
	var package_state: C_PackageState = cargo.get_component(C_PackageState) as C_PackageState
	return package_state != null and package_state.damage == C_PackageState.Damage.DESTROYED


## Commits one supported settled cargo binding and its reversible lifecycle effects.
static func load_supported(cart: E_TransportCart, cargo: Entity) -> bool:
	if not EntityAvailability.contains(cart, ECS.world) or not loadable(cargo):
		return false

	var body: RigidBody3D = cargo as Node as RigidBody3D
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	var elapsed: float = float(config.settling.get(cargo.get_instance_id(), 0.0))
	if elapsed < config.cargo_settle_seconds or (body.linear_velocity - config.actual_velocity).length() > config.cargo_settle_speed \
			or not CartCargoGeometry.supported(body, cart):
		return false

	if CartCargoQueries.relationship(cargo) != null:
		return false

	var cart_body: PhysicsBody3D = cart as Node as PhysicsBody3D
	if cart_body == null:
		return false

	var data: R_CartCargo = R_CartCargo.new()
	data.local_pose = cart_body.global_transform.affine_inverse() * body.global_transform
	var binding: Relationship = Relationship.new(data, cart)
	cargo.add_relationship(binding)
	if not data.lifecycle_applied and not cargo_added(cargo, binding):
		cargo.remove_relationship(binding)
	return data.lifecycle_applied and CartCargoQueries.relationship(cargo) == binding

#endregion
