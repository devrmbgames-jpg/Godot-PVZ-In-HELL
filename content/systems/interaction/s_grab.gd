extends System
class_name S_Grab

#region Constants
const ROTATION_SENSITIVITY: float = 0.006
const MIN_MASS: float = 0.001
const ROTATION_EPSILON: float = 0.00001
#endregion


#region GECS
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_InteractionTargeting] }


func query() -> QueryBuilder:
	return q.with_all([C_Controller, C_Interactor, C_GrabControl, C_CarryLoad])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for holder: Entity in entities:
		# Flush after iteration so relationship changes cannot move the active archetype.
		cmd.add_custom(handle_input.bind(holder))
#endregion


#region Public API
static func handle_input(holder: Entity) -> void:
	if not is_instance_valid(holder):
		return
	
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var controller: C_Controller = holder.get_component(C_Controller) as C_Controller
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	if control == null or controller == null or interactor == null:
		return
	
	var held: Entity = held_object(holder)
	if held != null:
		var body: RigidBody3D = held as Node as RigidBody3D
		var interactable: C_Interactable = held.get_component(C_Interactable) as C_Interactable
		var is_invalid: bool = (
			not entity_available(held) or 
			body == null or 
			body.freeze or 
			interactable == null or 
			not interactable.enabled or 
			not held.has_component(C_Grabbable)
		)
		if is_invalid :
			release(holder, held)
			held = null
	
	if not holder_available(holder):
		if held != null:
			release(holder, held)
		
		interactor.prompt_text = ""
		return
	
	InteractionActions.handle_input(holder)


static func try_pickup(holder: Entity, target: Entity) -> bool:
	if not holder_available(holder) or not entity_available(target) or holder == target:
		return false
	
	var anchor: Node3D = object_anchor(holder, target)
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	var body: RigidBody3D = target as Node as RigidBody3D
	var config: C_Grabbable = target.get_component(C_Grabbable) as C_Grabbable
	var interactable: C_Interactable = target.get_component(C_Interactable) as C_Interactable
	
	var is_invalid: bool = (
		not is_instance_valid(anchor) or interactor == null or control == null
		or load_state == null or body == null or config == null
		or interactable == null or not interactable.enabled or body.freeze
	)
	
	if is_invalid :
		return false
	
	if held_object(holder) != null or held_relationship(target) != null:
		return false
	
	# Revalidate range and line of sight at the command boundary (also for API callers).
	if not within_pickup_reach(holder, target):
		return false
	
	var grip_data: C_HeldBy = C_HeldBy.new()
	grip_data.hold_distance = carry_distance(control, config)
	grip_data.rotation_offset = (
		anchor.global_basis.orthonormalized().get_rotation_quaternion().inverse()
		* body.global_basis.orthonormalized().get_rotation_quaternion()
	).normalized()
	
	if config.hold_slot == C_Grabbable.HoldSlot.RIGHT_HAND:
		grip_data.rotation_offset = Quaternion.IDENTITY
	
	target.add_relationship(Relationship.new(grip_data, holder))
	
	return held_object(holder) == target


static func release(holder: Entity, held: Entity) -> void:
	if not is_instance_valid(held):
		if is_instance_valid(holder):
			reset_holder(holder)
		return
	var grip: Relationship = held_relationship(held)
	if grip != null and grip.target == holder:
		held.remove_relationship(grip)
		# World removal disconnects entity signals before notifying lifecycle listeners.
		# Cleanup is idempotent, so it also covers this teardown path.
		grip_removed(held, grip)


static func throw(holder: Entity, held: Entity) -> void:
	if not is_instance_valid(holder) or not is_instance_valid(held):
		return
	
	var grip: Relationship = held_relationship(held)
	if grip == null or grip.target != holder:
		return
	
	var config: C_Grabbable = held.get_component(C_Grabbable) as C_Grabbable
	var controller: C_Controller = holder.get_component(C_Controller) as C_Controller
	var body: RigidBody3D = held as Node as RigidBody3D
	
	if config == null or controller == null or body == null:
		release(holder, held)
		return
	
	var impulse: Vector3 = throw_impulse(
		controller.direction_look,
		config.throw_velocity,
		body.mass,
	)
	
	release(holder, held)
	body.sleeping = false
	body.apply_central_impulse(impulse)


static func integrate_forces(entity: Entity, state: PhysicsDirectBodyState3D) -> void:
	var grip: Relationship = held_relationship(entity)
	if grip == null:
		return
	
	var holder: Entity = grip.target as Entity
	var config: C_Grabbable = entity.get_component(C_Grabbable) as C_Grabbable
	var anchor: Node3D = object_anchor(holder, entity)
	
	var is_invalid := (
		not holder_available(holder) or not entity_available(entity)
		or config == null or not is_instance_valid(anchor)
	)
	if is_invalid :
		release(holder, entity)
		return
	
	var interactable: C_Interactable = entity.get_component(C_Interactable) as C_Interactable
	var body: RigidBody3D = entity as Node as RigidBody3D
	if body == null or body.freeze or interactable == null or not interactable.enabled:
		release(holder, entity)
		return
	
	var grip_data: C_HeldBy = grip.relation as C_HeldBy
	var desired_position: Vector3 = (
		anchor.global_position - anchor.global_basis.z * grip_data.hold_distance
	)
	
	var position_error: Vector3 = desired_position - state.transform.origin
	if position_error.length() > config.break_distance:
		release(holder, entity)
		return
	
	var anchor_velocity: Vector3 = Vector3.ZERO
	if grip_data.anchor_sample_valid and state.step > 0.0:
		anchor_velocity = (desired_position - grip_data.previous_anchor_position) / state.step
	
	grip_data.previous_anchor_position = desired_position
	grip_data.anchor_sample_valid = true
	var body_mass: float = 1.0 / maxf(state.inverse_mass, MIN_MASS)
	state.apply_central_force(
		position_force(
			position_error,
			anchor_velocity - state.linear_velocity,
			state.total_gravity,
			body_mass,
			config,
		)
	)
	
	var desired_rotation: Quaternion = (
		anchor.global_basis.orthonormalized().get_rotation_quaternion() * grip_data.rotation_offset
	).normalized()
	
	state.angular_velocity = rotation_velocity(
		state.transform.basis.orthonormalized().get_rotation_quaternion(),
		desired_rotation,
		state.step,
		config,
	)
	
#endregion


#region Lifecycle transitions
## Called by O_GrabLifecycle for any relationship producer, not just try_pickup.
static func grip_added(held: Entity, grip: Relationship) -> bool:
	var holder: Entity = grip.target as Entity
	var body: RigidBody3D = held as Node as RigidBody3D
	var config: C_Grabbable = held.get_component(C_Grabbable) as C_Grabbable
	var is_invalid: bool = (
		not holder_available(holder) or not entity_available(held) or body == null
		or config == null or not is_instance_valid(object_anchor(holder, held))
	)
	if is_invalid :
		return false
	
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if control == null or load_state == null:
		return false
	
	if held_relationship(held) != grip or held_object(holder) != null:
		return false
	
	var grip_data: C_HeldBy = grip.relation as C_HeldBy
	grip_data.lifecycle_applied = true
	if grip_data.hold_distance <= 0.0:
		grip_data.hold_distance = carry_distance(control, config)
	grip_data.previous_can_sleep = body.can_sleep
	
	body.can_sleep = false
	body.sleeping = false
	
	var holder_body: PhysicsBody3D = holder as Node as PhysicsBody3D
	if holder_body != null and not body.get_collision_exceptions().has(holder_body):
		body.add_collision_exception_with(holder_body)
		grip_data.added_collision_exception = true
	
	control.held_object = held
	
	load_state.active = true
	load_state.speed_multiplier = clampf(config.movement_speed_multiplier, 0.0, 1.0)
	load_state.acceleration_multiplier = clampf(config.movement_acceleration_multiplier, 0.0, 1.0)
	
	var cleanup: Callable = release.bind(holder, held)
	
	if not held.tree_exiting.is_connected(cleanup):
		held.tree_exiting.connect(cleanup)
	
	if not holder.tree_exiting.is_connected(cleanup):
		holder.tree_exiting.connect(cleanup)
	
	return true


static func grip_removed(held: Entity, grip: Relationship) -> void:
	var grip_data: C_HeldBy = grip.relation as C_HeldBy
	if not grip_data.lifecycle_applied:
		return
	
	grip_data.lifecycle_applied = false
	var holder: Entity = grip.target as Entity if is_instance_valid(grip.target) else null
	var body: RigidBody3D = held as Node as RigidBody3D
	if is_instance_valid(holder):
		var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
		if control != null and control.held_object == held:
			reset_holder(holder)
	
	var cleanup: Callable = release.bind(holder, held)
	if is_instance_valid(held) and held.tree_exiting.is_connected(cleanup):
		held.tree_exiting.disconnect(cleanup)
	
	if is_instance_valid(holder) and holder.tree_exiting.is_connected(cleanup):
		holder.tree_exiting.disconnect(cleanup)
	
	if body != null:
		if grip_data.added_collision_exception and is_instance_valid(holder):
			var holder_body: PhysicsBody3D = holder as Node as PhysicsBody3D
			if holder_body != null:
				body.remove_collision_exception_with(holder_body)
		body.can_sleep = grip_data.previous_can_sleep


static func entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	
	var grip: Relationship = held_relationship(entity)
	if grip != null:
		entity.remove_relationship(grip)
		grip_removed(entity, grip)
	
	var held: Entity = held_object(entity)
	if held != null:
		release(entity, held)


static func reset_holder(holder: Entity) -> void:
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	if control != null:
		var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
		if interactor != null and interactor.target == control.held_object:
			interactor.target = null
		control.held_object = null
		control.rotation_active = false
	
	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if load_state != null:
		load_state.active = false
		load_state.speed_multiplier = 1.0
		load_state.acceleration_multiplier = 1.0
	
#endregion


#region Position and rotation math
static func position_force(
	position_error: Vector3,
	velocity_error: Vector3,
	gravity: Vector3,
	body_mass: float,
	config: C_Grabbable,
) -> Vector3:
	var acceleration: Vector3 = (
		position_error * config.position_stiffness + velocity_error * config.position_damping
		- gravity
	)
	return (acceleration * body_mass).limit_length(maxf(config.max_hold_force, 0.0))


static func rotation_velocity(
	current: Quaternion,
	desired: Quaternion,
	step: float,
	config: C_Grabbable,
) -> Vector3:
	var error: Quaternion = (desired * current.inverse()).normalized()
	if error.w < 0.0:
		error = -error
	
	var axis_vector: Vector3 = Vector3(error.x, error.y, error.z)
	var rotation_error: Vector3 = Vector3.ZERO
	if axis_vector.length() > ROTATION_EPSILON:
		rotation_error = axis_vector.normalized() * 2.0 * atan2(axis_vector.length(), error.w)
	
	if step <= 0.0:
		return Vector3.ZERO
	
	return (rotation_error / step).limit_length(maxf(config.max_rotation_speed, 0.0))


static func rotated_offset(offset: Quaternion, look_delta: Vector2) -> Quaternion:
	return (
		Quaternion(Vector3.UP, -look_delta.x * ROTATION_SENSITIVITY)
		* Quaternion(Vector3.RIGHT, -look_delta.y * ROTATION_SENSITIVITY) * offset
	).normalized()


static func throw_impulse(direction: Vector3, velocity_change: float, body_mass: float) -> Vector3:
	return direction.normalized() * maxf(velocity_change, 0.0) * body_mass
#endregion


#region Queries and validation
static func held_relationship(entity: Entity) -> Relationship:
	if not is_instance_valid(entity):
		return null
	
	# Read the authoritative local relationships without allocating query patterns.
	for grip: Relationship in entity.relationships:
		if grip.relation is C_HeldBy:
			return grip
		
	return null


static func held_object(holder: Entity) -> Entity:
	if not is_instance_valid(holder):
		return null
	
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	if control == null:
		return null
	
	if is_instance_valid(control.held_object):
		var grip: Relationship = held_relationship(control.held_object)
		if grip != null and grip.target == holder:
			return control.held_object
	
	reset_holder(holder)
	return null


static func interaction_raycast(holder: Entity) -> RayCast3D:
	if not is_instance_valid(holder):
		return null
	
	return holder.get("interaction_ray_cast") as RayCast3D


static func hold_anchor(holder: Entity) -> Node3D:
	if not is_instance_valid(holder):
		return null
	
	return holder.get("hold_anchor") as Node3D


static func object_anchor(holder: Entity, target: Entity) -> Node3D:
	if not is_instance_valid(holder) or not is_instance_valid(target):
		return null
	
	var config: C_Grabbable = target.get_component(C_Grabbable) as C_Grabbable
	
	if config == null:
		return null
	
	match config.hold_slot:
		C_Grabbable.HoldSlot.CARRY:
			return hold_anchor(holder)
	
		C_Grabbable.HoldSlot.RIGHT_HAND:
			return holder.get("right_hand_slot") as Node3D

	return null

# TODO проверить что реализовано правильно
static func within_pickup_reach(holder: Entity, target: Entity) -> bool:
	if not is_instance_valid(holder) or not is_instance_valid(target):
		return false
	
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	var raycast: RayCast3D = interaction_raycast(holder)
	
	if control == null or interactor == null or not is_instance_valid(raycast):
		return false
	
	# Сохраняем прежнее правило:
	# target должен быть первым объектом под RayCast.
	# Это одновременно проверяет line of sight.
	if S_InteractionTargeting.find_target(holder, interactor) != target:
		return false
	
	if not raycast.is_colliding():
		return false
	
	# pickup_distance ограничивает именно возможность взять предмет,
	# независимо от общей interaction_distance.
	var hit_distance: float = raycast.global_position.distance_to(raycast.get_collision_point())
	
	return hit_distance <= maxf(control.pickup_distance, 0.0)

# TODO проверить что реализовано правильно
static func carry_distance(control: C_GrabControl, config: C_Grabbable) -> float:
	if control == null or config == null:
		return 0.0
	
	# Hand slot сам является конечной точкой предмета.
	# Поэтому дополнительного смещения вдоль -Z нет.
	if config.hold_slot != C_Grabbable.HoldSlot.CARRY:
		return 0.0
	
	# Предмет может переопределить стандартную дистанцию.
	if config.hold_distance >= 0.0:
		return config.hold_distance

	return control.hold_distance

# TODO проверить что реализовано правильно
static func entity_available(entity: Entity) -> bool:
	return (
		is_instance_valid(entity) and not entity.is_queued_for_deletion()
		and entity.is_inside_tree() and entity.enabled and is_instance_valid(ECS.world)
		and ECS.world.entity_to_archetype.has(entity)
	)


static func holder_available(holder: Entity) -> bool:
	if not entity_available(holder):
		return false
	
	var motion: C_Motion = holder.get_component(C_Motion) as C_Motion
	var health: C_Health = holder.get_component(C_Health) as C_Health
	return (motion == null or motion.control_enabled) and (health == null or health.value > 0.0)
#endregion
