extends System
## Owns exclusive cart Push lifecycle and fixed-speed physical cart/actor integration.
class_name S_Push

const DIRECTION_EPSILON: float = 0.0001


#region GECS
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_InteractionTargeting], Runs.Before: [S_Grab] }


func query() -> QueryBuilder:
	return q.with_all([C_Controller, C_PushControl])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for actor: Entity in entities:
		cmd.add_custom(_validate_actor.bind(actor))
#endregion


#region Public lifecycle
## Checks exclusive capacity, body state, front distance and pickup LOS without side effects.
static func can_begin(actor: Entity, cart: Entity) -> bool:
	if not _valid_pair(actor, cart):
		return false
	if not actor.has_component(C_GrabControl) or not actor.has_component(C_PushControl):
		return false
	if pushed_object(actor) != null or relationship(cart) != null:
		return false
	if InteractionControlFocus.current(actor) >= InteractionControlFocus.Priority.PUSH:
		return false

	return S_Grab.within_pickup_reach(actor, cart)


## Acquires a separate Push relation after command-boundary validation.
static func try_begin(actor: Entity, cart: Entity) -> bool:
	if not can_begin(actor, cart):
		return false

	cart.add_relationship(Relationship.new(C_PushedBy.new(), actor))
	return pushed_object(actor) == cart


## Stops propulsion and releases only this cart's capture, preserving all Grab slots.
static func end(actor: Entity, cart: Entity) -> void:
	var relation: Relationship = relationship(cart)
	if relation == null or relation.target != actor:
		return

	cart.remove_relationship(relation)
	push_removed(cart, relation)


## Observer entry point; rejects duplicate/external invalid relationships before side effects.
static func push_added(cart: Entity, relation: Relationship) -> bool:
	var actor: Entity = relation.target as Entity
	if not _valid_pair(actor, cart) or relationship(cart) != relation:
		return false

	var control: C_PushControl = actor.get_component(C_PushControl)
	if control == null or not actor.has_component(C_GrabControl):
		return false
	if pushed_object(actor) != null:
		return false

	var data: C_PushedBy = relation.relation as C_PushedBy
	var body: RigidBody3D = cart as Node as RigidBody3D
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


## Idempotent teardown also works when World removal disconnects relation signals first.
static func push_removed(cart: Entity, relation: Relationship) -> void:
	var data: C_PushedBy = relation.relation as C_PushedBy
	if not data.lifecycle_applied:
		return

	data.lifecycle_applied = false
	var actor: Entity = relation.target as Entity
	var cleanup: Callable = end.bind(actor, cart)
	if is_instance_valid(actor):
		InteractionControlFocus.release(actor, data.capture_token)
		var control: C_PushControl = actor.get_component(C_PushControl)
		if control != null and control.pushed_object == cart:
			control.pushed_object = null
		if actor.tree_exiting.is_connected(cleanup):
			actor.tree_exiting.disconnect(cleanup)

	if is_instance_valid(cart):
		(cart as Node as RigidBody3D).can_sleep = data.previous_can_sleep
		if cart.tree_exiting.is_connected(cleanup):
			cart.tree_exiting.disconnect(cleanup)


## World lifecycle entry point for either participant.
static func entity_unavailable(entity: Entity) -> void:
	var relation: Relationship = relationship(entity)
	if relation != null:
		end(relation.target as Entity, entity)

	var cart: Entity = pushed_object(entity)
	if cart != null:
		end(entity, cart)
#endregion


#region Physics
## Sets motor velocity on the physics step; collision response and gravity stay physical.
static func integrate_cart(cart: Entity, state: PhysicsDirectBodyState3D) -> void:
	var relation: Relationship = relationship(cart)
	if relation == null:
		return

	var actor: Entity = relation.target as Entity
	if not _valid_pair(actor, cart):
		end(actor, cart)
		return

	var desired_velocity: Vector3 = Vector3.ZERO
	var desired_turn: float = 0.0
	if InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.PUSH:
		var controller: C_Controller = actor.get_component(C_Controller)
		var config: C_Pushable = cart.get_component(C_Pushable)
		if controller.move_axis.y < -DIRECTION_EPSILON:
			desired_velocity = _forward(cart) * config.forward_speed
		desired_turn = -signf(controller.move_axis.x) * config.turn_speed

	state.linear_velocity = Vector3(desired_velocity.x, state.linear_velocity.y, desired_velocity.z)
	state.angular_velocity = Vector3(0.0, desired_turn, 0.0)


## Replaces only planar locomotion while pushing; follows the handle through body velocity.
static func integrate_actor(actor: Entity, state: PhysicsDirectBodyState3D) -> bool:
	var cart: Entity = pushed_object(actor)
	if (
		cart == null
		or InteractionControlFocus.current(actor) != InteractionControlFocus.Priority.PUSH
	):
		return false
	if not _valid_pair(actor, cart):
		end(actor, cart)
		return false
	if state.step <= 0.0:
		return true

	var config: C_Pushable = cart.get_component(C_Pushable)
	var body: RigidBody3D = cart as Node as RigidBody3D
	var handle_position: Vector3 = body.global_position - _forward(cart) * config.handle_distance
	var correction: Vector3 = handle_position - state.transform.origin
	correction.y = 0.0
	var correction_speed: Vector3 = (correction / state.step).limit_length(config.follow_speed)
	var desired: Vector3 = body.linear_velocity + correction_speed
	desired = desired.limit_length(config.forward_speed + config.follow_speed)
	state.linear_velocity = Vector3(desired.x, state.linear_velocity.y, desired.z)

	return true
#endregion


#region Queries
## Reads the relation authority without allocating a GECS query.
static func relationship(cart: Entity) -> Relationship:
	if is_instance_valid(cart):
		for relation: Relationship in cart.relationships:
			if relation.relation is C_PushedBy:
				return relation

	return null


## Returns a validated derived actor cache; never use it to create ownership.
static func pushed_object(actor: Entity) -> Entity:
	if not is_instance_valid(actor):
		return null

	var control: C_PushControl = actor.get_component(C_PushControl)
	if control == null:
		return null

	var relation: Relationship = relationship(control.pushed_object)
	if relation != null and relation.target == actor:
		return control.pushed_object

	control.pushed_object = null
	return null
#endregion


#region Private helpers
static func _validate_actor(actor: Entity) -> void:
	var cart: Entity = pushed_object(actor)
	if cart != null and not _valid_pair(actor, cart):
		end(actor, cart)


static func _valid_pair(actor: Entity, cart: Entity) -> bool:
	if not S_Grab.holder_available(actor) or not S_Grab.entity_available(cart):
		return false
	if cart.has_component(C_Grabbable) or not actor.has_component(C_Controller):
		return false

	var config: C_Pushable = cart.get_component(C_Pushable)
	var interactable: C_Interactable = cart.get_component(C_Interactable)
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
	var controller: C_Controller = actor.get_component(C_Controller)
	var facing: Vector3 = controller.direction_look
	facing.y = 0.0
	if offset.normalized().dot(facing.normalized()) < config.minimum_front_dot:
		return false

	return _clear_path(actor, body)


static func _clear_path(actor: Entity, body: RigidBody3D) -> bool:
	var anchor: Node3D = S_Grab.hold_anchor(actor)
	if not is_instance_valid(anchor):
		return false

	var excluded: Array[RID] = []
	var actor_body: CollisionObject3D = actor as Node as CollisionObject3D
	if actor_body != null:
		excluded.append(actor_body.get_rid())
	for slot_index: int in 3:
		var held_entity: Entity = S_Grab.held_in_slot(actor, slot_index)
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


static func _forward(cart: Entity) -> Vector3:
	var forward: Vector3 = -(cart as Node as Node3D).global_basis.z
	forward.y = 0.0
	return forward.normalized()
#endregion
