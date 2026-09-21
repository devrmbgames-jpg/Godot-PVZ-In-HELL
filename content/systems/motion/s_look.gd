extends System
class_name S_Look


const ANGLE_EPSILON: float = 0.001


static func integrate_forces(
	entity: E_RigidBodyCharacter,
	state: PhysicsDirectBodyState3D
) -> void:
	var controller := entity.get_component(
		C_Controller
	) as C_Controller
	
	var look := entity.get_component(
		C_Look
	) as C_Look
	
	if controller == null:
		return
	
	if look == null:
		return
	
	var look_direction := controller.direction_look
	
	if look_direction.is_zero_approx():
		return
	
	look_direction = look_direction.normalized()
	
	var max_rotation_step := deg_to_rad(
		look.look_acceleration
	) * state.step
	
	_integrate_yaw(
		entity,
		state,
		look,
		controller,
		look_direction,
		max_rotation_step
	)
	
	_integrate_pitch(
		entity,
		look_direction,
		max_rotation_step
	)


static func _integrate_yaw(
	entity: E_RigidBodyCharacter,
	state: PhysicsDirectBodyState3D,
	look: C_Look,
	controller: C_Controller,
	look_direction: Vector3,
	max_rotation_step: float
) -> void:
	var flat_look_direction := Vector3(
		look_direction.x,
		0.0,
		look_direction.z
	)
	
	if flat_look_direction.is_zero_approx():
		return
	
	flat_look_direction = flat_look_direction.normalized()
	
	var body_forward := -state.transform.basis.z
	body_forward.y = 0.0
	
	if body_forward.is_zero_approx():
		return
	
	body_forward = body_forward.normalized()
	
	var body_yaw := atan2(
		-body_forward.x,
		-body_forward.z
	)
	
	var look_yaw := atan2(
		-flat_look_direction.x,
		-flat_look_direction.z
	)
	
	# ---------------------------------------------------------------------
	# Если персонаж движется — плавно разворачиваем тело в сторону движения.
	# ---------------------------------------------------------------------
	
	var motion_direction := controller.direction_motion
	motion_direction.y = 0.0
	
	if not motion_direction.is_zero_approx():
		motion_direction = motion_direction.normalized()
		
		var motion_yaw := atan2(
			-motion_direction.x,
			-motion_direction.z
		)
		
		var motion_rotation_step := deg_to_rad(
			look.motion_alignment_acceleration
		) * state.step
		
		var new_body_yaw_motion := _move_toward_angle(
			body_yaw,
			motion_yaw,
			motion_rotation_step
		)
		
		var transform_motion := state.transform
		transform_motion.basis = Basis(
			Vector3.UP,
			new_body_yaw_motion
		)
		state.transform = transform_motion
		
		body_yaw = new_body_yaw_motion
	
	# ---------------------------------------------------------------------
	# Голова всегда смотрит в direction_look относительно текущего тела.
	# ---------------------------------------------------------------------
	
	var relative_yaw := angle_difference(
		body_yaw,
		look_yaw
	)
	
	var head_limit := deg_to_rad(
		look.head_yaw_limit
	)
	
	var desired_head_yaw := clampf(
		relative_yaw,
		-head_limit,
		head_limit
	)
	
	if entity.head_axis_y != null:
		entity.head_axis_y.rotation.y = (
			_move_toward_angle(
				entity.head_axis_y.rotation.y,
				desired_head_yaw,
				max_rotation_step
			)
		)
	
	# Пока движемся, направление корпуса уже определяется движением.
	if not motion_direction.is_zero_approx():
		return
	
	# ---------------------------------------------------------------------
	# Стоим на месте:
	# сначала поворачивается голова, затем тело.
	# ---------------------------------------------------------------------
	
	if absf(relative_yaw) <= head_limit:
		return
	
	if entity.head_axis_y != null:
		if absf(
			angle_difference(
				entity.head_axis_y.rotation.y,
				desired_head_yaw
			)
		) > ANGLE_EPSILON:
			return
	
	var target_body_yaw := (
		look_yaw
		- signf(relative_yaw) * head_limit
	)
	
	var new_body_yaw := _move_toward_angle(
		body_yaw,
		target_body_yaw,
		max_rotation_step
	)
	
	var transform := state.transform
	transform.basis = Basis(
		Vector3.UP,
		new_body_yaw
	)
	
	state.transform = transform


static func _integrate_pitch(
	entity: E_RigidBodyCharacter,
	look_direction: Vector3,
	max_rotation_step: float
) -> void:
	if entity.head_axis_x == null:
		return
	
	var horizontal_length := Vector2(
		look_direction.x,
		look_direction.z
	).length()
	
	var target_pitch := atan2(
		look_direction.y,
		horizontal_length
	)
	
	entity.head_axis_x.rotation.x = (
		_move_toward_angle(
			entity.head_axis_x.rotation.x,
			target_pitch,
			max_rotation_step
		)
	)


static func _move_toward_angle(
	current: float,
	target: float,
	max_delta: float
) -> float:
	var difference := angle_difference(
		current,
		target
	)
	
	if absf(difference) <= max_delta:
		return target
	
	return current + signf(difference) * max_delta
