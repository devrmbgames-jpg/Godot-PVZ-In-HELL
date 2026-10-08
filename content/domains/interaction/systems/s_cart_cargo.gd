extends System
## Owns cargo membership sampling and settling clocks; cart/cargo callbacks retain physical motion.
class_name S_CartCargo

#region Scheduled native-space sampling
## Reads the latest completed Jolt space at the Interaction stage before this frame's cart callback.
func deps() -> Dictionary[int, Array]:
	return {Runs.Before: [S_Grab, S_InteractionInput]}


## Selects participating authored transport carts.
func query() -> QueryBuilder:
	return q.with_all([C_CartTransport]).enabled()


## Captures cart/Component/physics-frame identity before queued membership changes.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return

	for entity: Entity in entities:
		var cart: E_TransportCart = entity as E_TransportCart
		assert(cart != null, "C_CartTransport requires the authored E_TransportCart physical root")
		var config: C_CartTransport = cart.get_component(C_CartTransport) as C_CartTransport
		cmd.add_custom(_sample_membership.bind(weakref(cart), config, Engine.get_physics_frames(), delta))


func _sample_membership(cart_reference: WeakRef, config: C_CartTransport, physics_frame: int, delta: float) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var cart: E_TransportCart = cart_reference.get_ref() as E_TransportCart

	# Deferred support/timing cannot span a physical frame or a replaced load aggregate.
	if not EntityAvailability.contains(cart, _world) or cart.get_component(C_CartTransport) != config:
		return
	if physics_frame != Engine.get_physics_frames() or config.cargo_update_frame == physics_frame:
		return

	config.cargo_update_frame = physics_frame
	for loaded: Entity in config.cargo.duplicate():
		var binding: Relationship = CartCargoQueries.relationship(loaded)
		if binding == null or binding.target != cart or not GrabQueries.entity_available(loaded):
			CartCargoService.release(loaded)
			config.cargo.erase(loaded)

	var present: Dictionary[int, bool] = { }
	for node: Node3D in cart.get_cargo_area().get_overlapping_bodies():
		var candidate: Entity = node as Node as Entity
		if not CartCargoService.loadable(candidate):
			continue

		var body: RigidBody3D = node as RigidBody3D
		var instance_id: int = candidate.get_instance_id()
		present[instance_id] = true
		var relative_speed: float = (body.linear_velocity - config.actual_velocity).length()
		if relative_speed > config.cargo_settle_speed or not CartCargoGeometry.supported(body, cart):
			config.settling.erase(instance_id)
			continue

		var elapsed: float = float(config.settling.get(instance_id, 0.0)) + delta
		config.settling[instance_id] = elapsed
		if elapsed >= config.cargo_settle_seconds:
			CartCargoService.load_supported(cart, candidate)
			config.settling.erase(instance_id)

	for instance_id: int in config.settling.keys():
		if not present.has(instance_id):
			config.settling.erase(instance_id)


#endregion
