extends RefCounted
## Shared spring/rotation math for callback-driven and scriptless rigid-body Carry.
class_name GrabPhysicsSolver

const MIN_MASS: float = 0.001
const ROTATION_EPSILON: float = 0.00001
const ANCHOR_TRANSITION_SECONDS: float = 0.5


static func integrate_state(
	state: PhysicsDirectBodyState3D,
	anchor: Node3D,
	grip: C_HeldBy,
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
		_desired_rotation(anchor, grip),
		state.step,
		profile,
	)
	_commit_anchor_sample(anchor, grip, desired_position)
	return true


static func integrate_body(
	body: RigidBody3D,
	step: float,
	anchor: Node3D,
	grip: C_HeldBy,
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
		_desired_rotation(anchor, grip),
		step,
		profile,
	)
	_commit_anchor_sample(anchor, grip, desired_position)
	return true


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


static func _desired_position(anchor: Node3D, grip: C_HeldBy) -> Vector3:
	return anchor.global_position - anchor.global_basis.z * grip.hold_distance


static func _desired_rotation(anchor: Node3D, grip: C_HeldBy) -> Quaternion:
	return (
		anchor.global_basis.orthonormalized().get_rotation_quaternion()
		* grip.rotation_offset
	).normalized()


static func _sample_anchor(
	anchor: Node3D,
	grip: C_HeldBy,
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
	grip: C_HeldBy,
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
	grip: C_HeldBy,
	desired_position: Vector3,
) -> void:
	grip.previous_anchor_id = anchor.get_instance_id()
	grip.previous_anchor_position = desired_position
	grip.anchor_sample_valid = true
