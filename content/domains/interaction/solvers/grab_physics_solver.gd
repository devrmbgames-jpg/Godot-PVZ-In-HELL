extends RefCounted
## Общая физика пружины и вращения для callback-тел и обычного Carry без скрипта.
class_name GrabPhysicsSolver

const ROTATION_SENSITIVITY: float = 0.006
const MIN_MASS: float = 0.001
const ROTATION_EPSILON: float = 0.00001
const ANCHOR_TRANSITION_SECONDS: float = 0.5


#region Физические адаптеры
## Применяет силу и угловую скорость через PhysicsDirectBodyState3D; false требует освобождения хвата.
static func integrate_state(
	state: PhysicsDirectBodyState3D,
	anchor: Node3D,
	grip: R_HeldBy,
	profile: GrabControlProfile,
	allowed_break_distance: float,
) -> bool:
	if state == null or not is_instance_valid(anchor) or grip == null or profile == null:
		return false

	var desired_position: Vector3 = _desired_position(anchor, grip)
	var position_error: Vector3 = desired_position - state.transform.origin
	if not _sample_anchor(
		anchor,
		grip,
		state.step,
		position_error,
		allowed_break_distance,
	):
		return false

	var anchor_velocity: Vector3 = _sampled_anchor_velocity(
		anchor,
		grip,
		desired_position,
		state.step,
	)
	var body_mass: float = 1.0 / maxf(state.inverse_mass, MIN_MASS)
	state.apply_central_force(
		position_force(
			position_error,
			anchor_velocity - state.linear_velocity,
			state.total_gravity,
			body_mass,
			profile,
		)
	)
	state.angular_velocity = rotation_velocity(
		state.transform.basis.orthonormalized().get_rotation_quaternion(),
		_desired_rotation(anchor, grip, profile),
		state.step,
		profile,
	)
	_commit_anchor_sample(anchor, grip, desired_position)
	return true


## Применяет ту же пружину обычному RigidBody3D перед шагом; step в секундах, transform не меняет.
static func integrate_body(
	body: RigidBody3D,
	step: float,
	anchor: Node3D,
	grip: R_HeldBy,
	profile: GrabControlProfile,
	allowed_break_distance: float,
) -> bool:
	if (
		not is_instance_valid(body) or body.freeze or step <= 0.0
		or not is_instance_valid(anchor) or grip == null or profile == null
	):
		return false

	var desired_position: Vector3 = _desired_position(anchor, grip)
	var position_error: Vector3 = desired_position - body.global_position
	if not _sample_anchor(
		anchor,
		grip,
		step,
		position_error,
		allowed_break_distance,
	):
		return false

	var anchor_velocity: Vector3 = _sampled_anchor_velocity(
		anchor,
		grip,
		desired_position,
		step,
	)
	body.apply_central_force(
		position_force(
			position_error,
			anchor_velocity - body.linear_velocity,
			body.get_gravity(),
			body.mass,
			profile,
		)
	)
	body.angular_velocity = rotation_velocity(
		body.global_basis.orthonormalized().get_rotation_quaternion(),
		_desired_rotation(anchor, grip, profile),
		step,
		profile,
	)
	_commit_anchor_sample(anchor, grip, desired_position)
	return true


#endregion

#region Расчёт силы и скорости
## Рассчитывает ограниченную силу в ньютонах с массой, гравитацией и демпфированием.
static func position_force(
	position_error: Vector3,
	velocity_error: Vector3,
	gravity: Vector3,
	body_mass: float,
	profile: GrabControlProfile,
) -> Vector3:
	if profile == null:
		return Vector3.ZERO

	var acceleration: Vector3 = (
		position_error * profile.position_stiffness
		+ velocity_error * profile.position_damping
		- gravity
	)
	return (acceleration * maxf(body_mass, MIN_MASS)).limit_length(
		maxf(profile.max_hold_force, 0.0)
	)


## Рассчитывает кратчайший поворот как ограниченную угловую скорость в рад/с; step в секундах.
static func rotation_velocity(
	current: Quaternion,
	desired: Quaternion,
	step: float,
	profile: GrabControlProfile,
) -> Vector3:
	if profile == null or step <= 0.0:
		return Vector3.ZERO

	var error: Quaternion = (desired * current.inverse()).normalized()
	if error.w < 0.0:
		error = -error

	var axis_vector: Vector3 = Vector3(error.x, error.y, error.z)
	var rotation_error: Vector3 = Vector3.ZERO
	if axis_vector.length() > ROTATION_EPSILON:
		rotation_error = axis_vector.normalized() * 2.0 * atan2(axis_vector.length(), error.w)
	return (rotation_error / step).limit_length(maxf(profile.max_rotation_speed, 0.0))


#endregion

#region Точка удержания и её движение
static func _desired_position(anchor: Node3D, grip: R_HeldBy) -> Vector3:
	return anchor.global_position - anchor.global_basis.z * grip.hold_distance


static func _desired_rotation(anchor: Node3D, grip: R_HeldBy, profile: GrabControlProfile) -> Quaternion:
	var desired: Quaternion = (
		anchor.global_basis.orthonormalized().get_rotation_quaternion()
		* grip.rotation_offset
	).normalized()
	if not profile.keep_upright:
		return desired

	var basis: Basis = Basis(desired)
	var forward: Vector3 = -basis.z
	forward.y = 0.0
	if forward.length_squared() <= ROTATION_EPSILON:
		var right: Vector3 = basis.x
		right.y = 0.0
		forward = Vector3.UP.cross(right)
	return Basis.looking_at(forward.normalized(), Vector3.UP).get_rotation_quaternion()


static func _sample_anchor(
	anchor: Node3D,
	grip: R_HeldBy,
	step: float,
	position_error: Vector3,
	allowed_break_distance: float,
) -> bool:
	if grip.previous_anchor_id != 0 and grip.previous_anchor_id != anchor.get_instance_id():
		grip.anchor_transition_remaining = ANCHOR_TRANSITION_SECONDS
	grip.anchor_transition_remaining = maxf(0.0, grip.anchor_transition_remaining - step)
	return (
		grip.anchor_transition_remaining > 0.0
		or position_error.length() <= maxf(allowed_break_distance, 0.0)
	)


static func _sampled_anchor_velocity(
	anchor: Node3D,
	grip: R_HeldBy,
	desired_position: Vector3,
	step: float,
) -> Vector3:
	if (
		grip.anchor_sample_valid
		and grip.previous_anchor_id == anchor.get_instance_id()
		and step > 0.0
	):
		return (desired_position - grip.previous_anchor_position) / step
	return Vector3.ZERO


static func _commit_anchor_sample(
	anchor: Node3D,
	grip: R_HeldBy,
	desired_position: Vector3,
) -> void:
	grip.previous_anchor_id = anchor.get_instance_id()
	grip.previous_anchor_position = desired_position
	grip.anchor_sample_valid = true

#endregion

#region Entity physical callback and suspended-hand allowance
## В физическом callback применяет удержание по точке живой связи; не перемещает transform напрямую.
static func integrate_forces(entity: Entity, state: PhysicsDirectBodyState3D) -> void:
	var grip: Relationship = GrabQueries.held_relationship(entity)
	if grip == null:
		return

	var pending: R_HeldBy = grip.relation as R_HeldBy
	if not pending.lifecycle_applied:
		return

	var holder: Entity = grip.target as Entity
	var body: RigidBody3D = GrabQueries.physical_body(entity)
	var anchor: Node3D = GrabQueries.object_anchor(holder, entity)
	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	var profile: GrabControlProfile = grip_data.profile
	if (
		not GrabQueries.holder_available(holder) or not GrabQueries.entity_available(entity)
		or body == null or body.freeze or profile == null or not is_instance_valid(anchor)
	):
		GrabReleaseService.release(holder, entity, false)
		return

	var interactable: C_Interactable = entity.get_component(C_Interactable) as C_Interactable
	if interactable != null and not interactable.enabled:
		GrabReleaseService.release(holder, entity, false)
		return

	var break_limit: float = allowed_break_distance(
		holder,
		anchor,
		grip_data,
		profile,
	)
	if not GrabPhysicsSolver.integrate_state(
		state,
		anchor,
		grip_data,
		profile,
		break_limit,
	):
		GrabReleaseService.release(holder, entity, false)


## Computes the physical break allowance for suspended hands without changing ownership.
static func allowed_break_distance(
	holder: Entity,
	anchor: Node3D,
	grip_data: R_HeldBy,
	profile: GrabControlProfile,
) -> float:
	var allowed: float = profile.break_distance
	var hand_suspended: bool = (
		grip_data.slot != C_Grabbable.HoldSlot.CARRY
		and InteractionControlFocus.current(holder) != InteractionControlFocus.Priority.HANDS
	)
	if not hand_suspended:
		return allowed

	var hand_property: StringName = &"right_hand_slot"
	if grip_data.slot == C_Grabbable.HoldSlot.LEFT_HAND:
		hand_property = &"left_hand_slot"
	var normal_anchor: Node3D = holder.get(hand_property) as Node3D
	if is_instance_valid(normal_anchor):
		allowed += normal_anchor.global_position.distance_to(anchor.global_position)
	return allowed


#endregion

#region Manual rotation and throw impulse
## Применяет ручной поворот с ограничением авторских осей вращения.
static func rotated_offset(
	offset: Quaternion,
	look_delta: Vector2,
	axis: C_Grabbable.RotationAxis = C_Grabbable.RotationAxis.FREE,
) -> Quaternion:
	if axis == C_Grabbable.RotationAxis.Y_ONLY:
		return Quaternion(Vector3.UP, offset.get_euler().y - look_delta.x * ROTATION_SENSITIVITY)
	return (
		Quaternion(Vector3.UP, -look_delta.x * ROTATION_SENSITIVITY)
		* Quaternion(Vector3.RIGHT, -look_delta.y * ROTATION_SENSITIVITY) * offset
	).normalized()


## Преобразует изменение скорости в м/с и массу в кг в импульс тела.
static func throw_impulse(direction: Vector3, velocity_change: float, body_mass: float) -> Vector3:
	return direction.normalized() * maxf(velocity_change, 0.0) * body_mass
#endregion
