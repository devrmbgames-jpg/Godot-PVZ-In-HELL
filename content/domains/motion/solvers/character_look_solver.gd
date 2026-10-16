extends RefCounted
## Общая ориентация физического персонажа; native callback применяет рассчитанную позу.
class_name CharacterLookSolver

const ANGLE_EPSILON: float = 0.001


#region Физический вход
## Адаптирует общий расчёт к заимствованному native RigidBody state.
static func integrate_forces(entity: E_RigidBodyCharacter, state: PhysicsDirectBodyState3D) -> void:
	state.transform = step(entity, state.transform, state.step)


## Возвращает мировую позу корпуса и применяет локальный поворот головы; delta в секундах.
## Физическое тело остаётся владельцем применения позы.
static func step(entity: E_PhysicalCharacter, pose: Transform3D, delta: float) -> Transform3D:
	var grab_control: C_GrabControl = entity.get_component(C_GrabControl) as C_GrabControl
	if grab_control != null and grab_control.rotation_active:
		return pose

	var controller := entity.get_component(C_Controller) as C_Controller

	var look := entity.get_component(C_Look) as C_Look
	var carry_load: C_CarryLoad = entity.get_component(C_CarryLoad) as C_CarryLoad
	var strength: C_Strength = entity.get_component(C_Strength) as C_Strength
	var mobility_multiplier: float = CarryLoadPolicy.active_multiplier(carry_load, strength)

	if controller == null:
		return pose

	if look == null:
		return pose

	var look_direction := controller.direction_look

	if look_direction.is_zero_approx():
		return pose

	look_direction = look_direction.normalized()
	if look.direct_input:
		return _integrate_direct_look(entity, pose, look_direction)

	var max_rotation_step: float = (
		deg_to_rad(look.look_acceleration) * delta * mobility_multiplier
	)

	pose = _integrate_yaw(
		entity,
		pose,
		delta,
		look,
		controller,
		look_direction,
		max_rotation_step,
		mobility_multiplier,
	)

	_integrate_pitch(entity, look_direction, max_rotation_step)

	return pose

#endregion


#region Прямой ввод и ориентация
static func _integrate_direct_look(
	entity: E_PhysicalCharacter,
	pose: Transform3D,
	look_direction: Vector3,
) -> Transform3D:
	# Поворот корпуса остаётся у физического тела; камера применяет прямой ввод без дополнительного
	# лимита.
	var yaw: float = atan2(-look_direction.x, -look_direction.z)
	pose.basis = Basis(Vector3.UP, yaw)
	if entity.head_axis_y != null:
		entity.head_axis_y.rotation.y = 0.0
	if entity.head_axis_x != null:
		var horizontal_length: float = Vector2(look_direction.x, look_direction.z).length()
		entity.head_axis_x.rotation.x = atan2(look_direction.y, horizontal_length)
	return pose


static func _integrate_yaw(
	entity: E_PhysicalCharacter,
	pose: Transform3D,
	delta: float,
	look: C_Look,
	controller: C_Controller,
	look_direction: Vector3,
	max_rotation_step: float,
	mobility_multiplier: float,
) -> Transform3D:
	var flat_look_direction := Vector3(look_direction.x, 0.0, look_direction.z)

	if flat_look_direction.is_zero_approx():
		return pose

	flat_look_direction = flat_look_direction.normalized()

	var body_forward := -pose.basis.z
	body_forward.y = 0.0

	if body_forward.is_zero_approx():
		return pose

	body_forward = body_forward.normalized()

	var body_yaw: float = atan2(-body_forward.x, -body_forward.z)

	var look_yaw: float = atan2(-flat_look_direction.x, -flat_look_direction.z)

	# ---------------------------------------------------------------------
	# Движение.
	#
	# Корпус в первую очередь ориентирован по направлению взгляда.
	#
	# Forward  -> корпус смотрит прямо.
	# Backward -> корпус смотрит прямо и персонаж пятится.
	# Left     -> корпус слегка разворачивается влево.
	# Right    -> корпус слегка разворачивается вправо.
	#
	# Для диагонального движения отклонение интерполируется автоматически.
	# ---------------------------------------------------------------------
	var motion_direction: Vector3 = controller.direction_motion
	motion_direction.y = 0.0

	var is_moving: bool = not motion_direction.is_zero_approx()

	if is_moving:
		motion_direction = motion_direction.normalized()

		# В Godot forward персонажа — -Z.
		# Для направления -Z этот cross даёт +X, то есть вправо.
		var look_right: Vector3 = (flat_look_direction.cross(Vector3.UP).normalized())

		# -1 = движение полностью влево
		#  0 = движение вперёд или назад
		# +1 = движение полностью вправо
		var lateral_motion: float = clampf(motion_direction.dot(look_right), -1.0, 1.0)

		var strafe_yaw_limit: float = deg_to_rad(look.strafe_body_yaw_limit)

		# В используемой системе yaw движение вправо соответствует
		# отрицательному углу.
		var body_yaw_offset: float = (-lateral_motion * strafe_yaw_limit)

		var motion_target_body_yaw: float = (look_yaw + body_yaw_offset)

		var motion_rotation_step: float = (
			deg_to_rad(look.motion_alignment_acceleration) * delta * mobility_multiplier
		)

		var motion_new_body_yaw: float = _move_toward_angle(
			body_yaw,
			motion_target_body_yaw,
			motion_rotation_step,
		)

		pose.basis = Basis(Vector3.UP, motion_new_body_yaw)

		body_yaw = motion_new_body_yaw

	# ---------------------------------------------------------------------
	# Голова компенсирует отклонение корпуса и продолжает смотреть
	# точно в direction_look.
	# ---------------------------------------------------------------------
	var relative_yaw: float = angle_difference(body_yaw, look_yaw)

	var head_limit: float = deg_to_rad(look.head_yaw_limit)

	var desired_head_yaw: float = clampf(relative_yaw, -head_limit, head_limit)

	if entity.head_axis_y != null:
		entity.head_axis_y.rotation.y = _move_toward_angle(
			entity.head_axis_y.rotation.y,
			desired_head_yaw,
			max_rotation_step,
		)

	# Во время движения корпус уже управляется логикой выше.
	if is_moving:
		return pose

	# ---------------------------------------------------------------------
	# Стоим на месте.
	#
	# Сначала голова доходит до своего лимита.
	# Затем начинает доворачиваться корпус.
	# ---------------------------------------------------------------------
	if absf(relative_yaw) <= head_limit:
		return pose

	if entity.head_axis_y != null:
		var head_yaw_error: float = angle_difference(
			entity.head_axis_y.rotation.y,
			desired_head_yaw,
		)

		if absf(head_yaw_error) > ANGLE_EPSILON:
			return pose

	var target_body_yaw: float = (look_yaw - signf(relative_yaw) * head_limit)

	var new_body_yaw: float = _move_toward_angle(body_yaw, target_body_yaw, max_rotation_step)

	pose.basis = Basis(Vector3.UP, new_body_yaw)
	return pose


static func _integrate_pitch(
	entity: E_PhysicalCharacter,
	look_direction: Vector3,
	max_rotation_step: float,
) -> void:
	if entity.head_axis_x == null:
		return

	var horizontal_length := Vector2(look_direction.x, look_direction.z).length()

	var target_pitch := atan2(look_direction.y, horizontal_length)

	entity.head_axis_x.rotation.x = (
		_move_toward_angle(entity.head_axis_x.rotation.x, target_pitch, max_rotation_step)
	)


static func _move_toward_angle(current: float, target: float, max_delta: float) -> float:
	var difference := angle_difference(current, target)

	if absf(difference) <= max_delta:
		return target

	return current + signf(difference) * max_delta

#endregion
