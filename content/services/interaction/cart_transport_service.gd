extends RefCounted
## Owns the exclusive cart-driver session. R_CartDrivenBy is sole authority.
class_name CartTransportService


static func relationship(cart: Entity) -> Relationship:
	if not is_instance_valid(cart):
		return null
	for candidate: Relationship in cart.relationships:
		if candidate.relation is R_CartDrivenBy:
			return candidate
	return null


static func can_begin(actor: Entity, cart: Entity) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.entity_available(cart):
		return false
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if config == null or relationship(cart) != null or current(actor) != null:
		return false
	if not actor.has_component(C_Controller) or not actor.has_component(C_GrabControl):
		return false
	if InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PUSH:
		return false
	return GrabService.within_pickup_reach(actor, cart)


static func begin(actor: Entity, cart: Entity) -> void:
	if not can_begin(actor, cart):
		return
	var data: R_CartDrivenBy = R_CartDrivenBy.new()
	var binding: Relationship = Relationship.new(data, actor)
	cart.add_relationship(binding)
	if not data.lifecycle_applied and not driver_added(cart, binding):
		cart.remove_relationship(binding)


static func end(cart: Entity) -> void:
	if not is_instance_valid(cart):
		return
	var binding: Relationship = relationship(cart)
	if binding == null:
		return
	cart.remove_relationship(binding)
	driver_removed(cart, binding)


static func current(actor: Entity) -> Entity:
	if not is_instance_valid(actor):
		return null
	var cache: C_CartDriver = actor.get_component(C_CartDriver) as C_CartDriver
	if cache == null or not GrabService.entity_available(cache.cart):
		return null
	var binding: Relationship = relationship(cache.cart)
	if binding != null and binding.target == actor:
		return cache.cart
	cache.cart = null
	return null


static func driver_added(cart: Entity, binding: Relationship) -> bool:
	var data: R_CartDrivenBy = binding.relation as R_CartDrivenBy
	var actor: Entity = binding.target as Entity
	if data == null or data.lifecycle_applied:
		return data != null
	if not GrabService.holder_available(actor) or not GrabService.entity_available(cart):
		return false
	if relationship(cart) != binding:
		return false
	var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
	if config == null or current(actor) != null:
		return false

	var cache: C_CartDriver = actor.get_component(C_CartDriver) as C_CartDriver
	if cache == null:
		cache = C_CartDriver.new()
		actor.add_component(cache)
	cache.cart = cart
	data.capture_token = InteractionControlFocus.acquire(
		actor,
		cart,
		InteractionControlFocus.Priority.TRANSPORT,
	)
	data.lifecycle_applied = true
	var cleanup: Callable = _on_driver_exiting.bind(cart)
	if not actor.tree_exiting.is_connected(cleanup):
		actor.tree_exiting.connect(cleanup)
	return true


static func driver_removed(cart: Entity, binding: Relationship) -> void:
	var data: R_CartDrivenBy = binding.relation as R_CartDrivenBy
	if data == null or not data.lifecycle_applied:
		return
	data.lifecycle_applied = false
	var actor: Entity = binding.target as Entity if is_instance_valid(binding.target) else null
	if is_instance_valid(actor):
		InteractionControlFocus.release(actor, data.capture_token)
		var cache: C_CartDriver = actor.get_component(C_CartDriver) as C_CartDriver
		if cache != null and cache.cart == cart:
			cache.cart = null
		var cleanup: Callable = _on_driver_exiting.bind(cart)
		if actor.tree_exiting.is_connected(cleanup):
			actor.tree_exiting.disconnect(cleanup)
	if is_instance_valid(cart):
		var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
		if config != null:
			config.drive_speed = 0.0


static func entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	if relationship(entity) != null:
		end(entity)
	var cache: C_CartDriver = entity.get_component(C_CartDriver) as C_CartDriver
	if cache != null and is_instance_valid(cache.cart):
		end(cache.cart)


static func driver_valid(body: CharacterBody3D, config: C_CartTransport, actor: Entity) -> bool:
	if body == null or config == null or not GrabService.holder_available(actor):
		return false
	var actor_node: Node3D = actor as Node as Node3D
	if actor_node == null:
		return false
	return body.global_position.distance_to(actor_node.global_position) <= config.focus_distance


static func handle_position(body: CharacterBody3D, config: C_CartTransport) -> Vector3:
	return body.global_position + body.global_basis.z * config.handle_distance


static func _on_driver_exiting(cart: Entity) -> void:
	end(cart)
