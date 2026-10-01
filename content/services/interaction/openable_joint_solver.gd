extends RefCounted
## Only joint motor requests are written. Physical progress is read from the body.
class_name OpenableJointSolver

const MOTION_EPSILON: float = 0.0001


static func step(entity: Entity, body: RigidBody3D, hinge: HingeJoint3D, slide: Generic6DOFJoint3D) -> void:
	var state: C_Openable = entity.get_component(C_Openable) as C_Openable
	if state == null or state.motion == null or not EntityAvailability.contains(entity, ECS.world):
		return
	var root: Node3D = entity as Node as Node3D
	var local: Transform3D = root.global_transform.affine_inverse() * body.global_transform
	var motion: DEF_OpenableMotion = state.motion
	var target_fraction: float = 1.0 if state.requested_open else 0.0
	if hinge != null:
		var closed: Quaternion = motion.closed_transform.basis.get_rotation_quaternion()
		var opened: Quaternion = motion.open_transform.basis.get_rotation_quaternion()
		var rotation: Quaternion = (closed.inverse() * opened).normalized()
		var angle: float = rotation.get_angle()
		if angle <= MOTION_EPSILON:
			return
		var axis: Vector3 = rotation.get_axis()
		var actual: Quaternion = (closed.inverse() * local.basis.get_rotation_quaternion()).normalized()
		var actual_angle: float = actual.get_angle() * actual.get_axis().dot(axis)
		OpenableService.report_fraction(state, clampf(actual_angle / angle, 0.0, 1.0))
		var error: float = target_fraction * angle - actual_angle
		var velocity: float = _motor_velocity(error, angle, state)
		var world_axis: Vector3 = root.global_basis * motion.closed_transform.basis * axis
		var axis_sign: float = world_axis.dot(hinge.global_basis.z)
		hinge.set("motor/enable", true)
		# These scenes bind the fixed frame as A and moving leaf as B:
		# joint-relative velocity has the opposite sign to B's world rotation.
		hinge.set("motor/target_velocity", -velocity * axis_sign)
		hinge.set("motor/max_impulse", motion.hinge_motor_max_impulse)
	elif slide != null:
		var travel: Vector3 = motion.open_transform.origin - motion.closed_transform.origin
		var distance: float = travel.length()
		if distance <= MOTION_EPSILON:
			return
		var actual_distance: float = (local.origin - motion.closed_transform.origin).dot(travel / distance)
		OpenableService.report_fraction(state, clampf(actual_distance / distance, 0.0, 1.0))
		var error: float = target_fraction * distance - actual_distance
		var velocity: float = _motor_velocity(error, distance, state)
		var axis: Vector3 = slide.global_basis.inverse() * root.global_basis * (travel / distance)
		slide.set("linear_motor_x/enabled", true)
		slide.set("linear_motor_y/enabled", true)
		slide.set("linear_motor_z/enabled", true)
		slide.set("linear_motor_x/target_velocity", velocity * axis.x)
		slide.set("linear_motor_y/target_velocity", velocity * axis.y)
		slide.set("linear_motor_z/target_velocity", velocity * axis.z)
		slide.set("linear_motor_x/force_limit", motion.slide_motor_force_limit)
		slide.set("linear_motor_y/force_limit", motion.slide_motor_force_limit)
		slide.set("linear_motor_z/force_limit", motion.slide_motor_force_limit)


static func _motor_velocity(error: float, extent: float, state: C_Openable) -> float:
	if state.locked or state.motion.duration_seconds <= 0.0:
		return 0.0
	var maximum: float = extent / state.motion.duration_seconds
	return clampf(error * state.motion.motor_response, -maximum, maximum)
