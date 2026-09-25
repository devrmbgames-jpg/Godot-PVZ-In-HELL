extends RefCounted
## Owns Push session validation, R_PushedBy lifecycle and derived reverse cache.
class_name PushService

const DIRECTION_EPSILON: float = 0.0001


static func can_begin(actor: Entity, cart: Entity) -> bool:
	if not valid_pair(actor, cart):
		return false
	if not actor.has_component(C_GrabControl) or not actor.has_component(C_PushControl):
		return false
	if pushed_object(actor) != null or relationship(cart) != null:
		return false
	if InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PUSH:
		return false
	return GrabService.within_pickup_reach(actor, cart)


static func try_begin(actor: Entity, cart: Entity) -> bool:
	if not can_begin(actor, cart):
		return false
	var data: R_PushedBy = R_PushedBy.new()
	var binding: Relationship = Relationship.new(data, actor)
	cart.add_relationship(binding)
	if not data.lifecycle_applied and not push_added(cart, binding):
		cart.remove_relationship(binding)
	return pushed_object(actor) == cart


static func end(actor: Entity, cart: Entity) -> void:
	var binding: Relationship = relationship(cart)
	if binding == null or binding.target != actor:
		return
	cart.remove_relationship(binding)
	push_removed(cart, binding)


static func push_added(cart: Entity, binding: Relationship) -> bool:
	var actor: Entity = binding.target as Entity
	if not valid_pair(actor, cart) or relationship(cart) != binding:
		return false

	var control: C_PushControl = actor.get_component(C_PushControl) as C_PushControl
	if control == null or not actor.has_component(C_GrabControl):
		return false
	if pushed_object(actor) != null:
		return false

	var data: R_PushedBy = binding.relation as R_PushedBy
	var body: RigidBody3D = cart as Node as RigidBody3D
	if data == null or body == null:
		return false
	data.previous_can_sleep = body.can_sleep
	data.capture_token = InteractionControlFocus.acquire(
		actor,
		cart,
		InteractionControlFocus.Priority.PUSH,
	)
	data.lifecycle_applied = true
	control.pushed_object = cart
	body.can_sleep = false
	body.sleeping = false

	var cleanup: Callable = end.bind(actor, cart)
	if not actor.tree_exiting.is_connected(cleanup):
		actor.tree_exiting.connect(cleanup)
	if not cart.tree_exiting.is_connected(cleanup):
		cart.tree_exiting.connect(cleanup)
	return true


static func push_removed(cart: Entity, binding: Relationship) -> void:
	var data: R_PushedBy = binding.relation as R_PushedBy
	if data == null or not data.lifecycle_applied:
		return
	data.lifecycle_applied = false
	var actor: Entity = binding.target as Entity if is_instance_valid(binding.target) else null
	var cleanup: Callable = end.bind(actor, cart)
	if is_instance_valid(actor):
		InteractionControlFocus.release(actor, data.capture_token)
		var control: C_PushControl = actor.get_component(C_PushControl) as C_PushControl
		if control != null and control.pushed_object == cart:
			control.pushed_object = null
		if actor.tree_exiting.is_connected(cleanup):
			actor.tree_exiting.disconnect(cleanup)

	if is_instance_valid(cart):
		var body: RigidBody3D = cart as Node as RigidBody3D
		if body != null:
			body.can_sleep = data.previous_can_sleep
		if cart.tree_exiting.is_connected(cleanup):
			cart.tree_exiting.disconnect(cleanup)


static func entity_unavailable(entity: Entity) -> void:
	var binding: Relationship = relationship(entity)
	if binding != null:
		end(binding.target as Entity, entity)
	var cart: Entity = pushed_object(entity)
	if cart != null:
		end(entity, cart)


static func relationship(cart: Entity) -> Relationship:
	if not is_instance_valid(cart):
		return null
	for binding: Relationship in cart.relationships:
		if binding.relation is R_PushedBy:
			return binding
	return null


static func pushed_object(actor: Entity) -> Entity:
	if not is_instance_valid(actor):
		return null
	var control: C_PushControl = actor.get_component(C_PushControl) as C_PushControl
	if control == null:
		return null
	var binding: Relationship = relationship(control.pushed_object)
	if binding != null and binding.target == actor:
		return control.pushed_object
	control.pushed_object = null
	return null


static func validate_actor(actor: Entity) -> void:
	var cart: Entity = pushed_object(actor)
	if cart != null and not valid_pair(actor, cart):
		end(actor, cart)


static func valid_pair(actor: Entity, cart: Entity) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.entity_available(cart):
		return false
	if cart.has_component(C_Grabbable) or not actor.has_component(C_Controller):
		return false

	var config: C_Pushable = cart.get_component(C_Pushable) as C_Pushable
	var interactable: C_Interactable = cart.get_component(C_Interactable) as C_Interactable
	var body: RigidBody3D = cart as Node as RigidBody3D
	var actor_body: Node3D = actor as Node as Node3D
	if config == null or interactable == null or body == null or actor_body == null:
		return false
	if not interactable.enabled or body.freeze:
		return false

	var offset: Vector3 = body.global_position - actor_body.global_position
	if offset.length() > config.focus_distance:
		return false
	offset.y = 0.0
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var facing: Vector3 = controller.direction_look
	facing.y = 0.0
	if offset.is_zero_approx() or facing.is_zero_approx():
		return false
	if offset.normalized().dot(facing.normalized()) < config.minimum_front_dot:
		return false
	return _clear_path(actor, body)


static func forward(cart: Entity) -> Vector3:
	var node: Node3D = cart as Node as Node3D
	if node == null:
		return Vector3.ZERO
	var direction: Vector3 = -node.global_basis.z
	direction.y = 0.0
	return direction.normalized()


static func _clear_path(actor: Entity, body: RigidBody3D) -> bool:
	var anchor: Node3D = GrabService.hold_anchor(actor)
	if not is_instance_valid(anchor):
		return false
	var excluded: Array[RID] = []
	var actor_body: CollisionObject3D = actor as Node as CollisionObject3D
	if actor_body != null:
		excluded.append(actor_body.get_rid())
	for slot_index: int in 3:
		var held_entity: Entity = GrabService.held_in_slot(actor, slot_index)
		var held: CollisionObject3D = held_entity as Node as CollisionObject3D
		if held != null:
			excluded.append(held.get_rid())
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		anchor.global_position,
		body.global_position,
		body.collision_mask,
		excluded,
	)
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.get("collider") == body
