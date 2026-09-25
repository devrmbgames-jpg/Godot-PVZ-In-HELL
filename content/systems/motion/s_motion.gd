extends System
## Integrates grounded/airborne actor motion, with Push owning planar motion while active.
class_name S_Motion

const INPUT_EPSILON: float = 0.0001
const DEFAULT_FRICTION: float = 1.0


## Главная точка входа locomotion.
##
## Вызывается непосредственно из:
##
##     E_RigidBodyCharacter._integrate_forces()
##
## S_Motion не обязан быть зарегистрирован в ECS World,
## если используется только как physics solver.
static func integrate_forces(entity: Entity, state: PhysicsDirectBodyState3D) -> void:
	var body := entity as Node as RigidBody3D

	if body == null:
		return

	var controller := entity.get_component(C_Controller) as C_Controller

	var motion := entity.get_component(C_Motion) as C_Motion

	if motion == null:
		return

	_apply_pending_impulse(state, motion)

	var floor_contact_index := _find_floor_contact(state, motion)

	_update_floor_state(state, motion, floor_contact_index)

	if controller == null:
		return

	if not motion.control_enabled:
		return
	if S_Push.integrate_actor(entity, state):
		return

	_integrate_regular_motion(
		state,
		controller,
		motion,
		entity.get_component(C_CarryLoad) as C_CarryLoad,
		entity.get_component(C_Strength) as C_Strength,
	)

# =========================================================================
# Locomotion
# =========================================================================


static func _integrate_regular_motion(
	state: PhysicsDirectBodyState3D,
	controller: C_Controller,
	motion: C_Motion,
	carry_load: C_CarryLoad,
	strength: C_Strength,
) -> void:
	var input_motion := controller.direction_motion

	# Обычный locomotion управляет только движением
	# относительно поверхности.
	#
	# Прыжки / падение / bounce не должны уничтожаться.
	input_motion.y = 0.0

	var input_strength := clampf(input_motion.length(), 0.0, 1.0)

	if input_strength <= INPUT_EPSILON:
		if motion.is_on_floor:
			_apply_ground_deceleration(state, motion)
		return

	var input_direction := input_motion.normalized()

	if motion.is_on_floor:
		_integrate_ground_motion(
			state,
			motion,
			input_direction,
			input_strength,
			carry_load,
			strength,
		)
	else:
		_integrate_air_motion(
			state,
			motion,
			input_direction,
			input_strength,
			carry_load,
			strength,
		)


static func _integrate_ground_motion(
	state: PhysicsDirectBodyState3D,
	motion: C_Motion,
	input_direction: Vector3,
	input_strength: float,
	carry_load: C_CarryLoad,
	strength: C_Strength,
) -> void:
	var wish_direction := input_direction.slide(motion.floor_normal)

	if wish_direction.length_squared() <= INPUT_EPSILON:
		return

	wish_direction = wish_direction.normalized()

	# Убираем боковой занос.
	_apply_ground_lateral_friction(state, motion, wish_direction)

	var acceleration: float = motion.ground_acceleration

	if motion.surface_friction_affects_control:
		var traction := clampf(motion.floor_friction, motion.minimum_ground_traction, 1.0)

		acceleration *= traction

	var relative_velocity := (state.linear_velocity - motion.floor_velocity)

	var wish_speed: float = effective_speed(motion, carry_load, strength) * input_strength

	_accelerate(state, relative_velocity, wish_direction, wish_speed, acceleration)


static func _integrate_air_motion(
	state: PhysicsDirectBodyState3D,
	motion: C_Motion,
	input_direction: Vector3,
	input_strength: float,
	carry_load: C_CarryLoad,
	strength: C_Strength,
) -> void:
	var wish_speed: float = effective_speed(motion, carry_load, strength) * input_strength

	_accelerate(
		state,
		state.linear_velocity,
		input_direction,
		wish_speed,
		motion.air_acceleration,
	)

# =========================================================================
# Acceleration
# =========================================================================


## Добавляет скорость только вдоль направления управления.
##
## ВАЖНО:
## функция не приводит весь velocity к target_velocity.
## Поэтому внешняя инерция сохраняется.
static func _accelerate(
	state: PhysicsDirectBodyState3D,
	current_velocity: Vector3,
	wish_direction: Vector3,
	wish_speed: float,
	acceleration: float,
) -> void:
	if acceleration <= 0.0:
		return

	var current_speed := current_velocity.dot(wish_direction)

	var speed_to_add := (wish_speed - current_speed)

	# Уже движемся в этом направлении достаточно быстро.
	#
	# Не тормозим:
	# возможно velocity появился от knockback,
	# падения, другого RigidBody и т.д.
	if speed_to_add <= 0.0:
		return

	var velocity_change := minf(speed_to_add, acceleration * state.step)

	state.linear_velocity += (wish_direction * velocity_change)


static func _apply_ground_deceleration(state: PhysicsDirectBodyState3D, motion: C_Motion) -> void:
	if not motion.is_on_floor:
		return

	var relative_velocity := (state.linear_velocity - motion.floor_velocity)

	# Скорость вдоль поверхности.
	var planar_velocity := relative_velocity.slide(motion.floor_normal)

	if planar_velocity.is_zero_approx():
		return

	var new_planar_velocity := planar_velocity.move_toward(
		Vector3.ZERO,
		motion.ground_deceleration * state.step,
	)

	var velocity_change := (new_planar_velocity - planar_velocity)

	state.linear_velocity += velocity_change


static func _apply_ground_lateral_friction(
	state: PhysicsDirectBodyState3D,
	motion: C_Motion,
	wish_direction: Vector3,
) -> void:
	var relative_velocity := (state.linear_velocity - motion.floor_velocity)

	var planar_velocity := relative_velocity.slide(motion.floor_normal)

	# Та часть скорости, которая совпадает
	# с желаемым направлением.
	var forward_velocity := (wish_direction * planar_velocity.dot(wish_direction))

	# Всё остальное — боковое скольжение.
	var lateral_velocity := (planar_velocity - forward_velocity)

	if lateral_velocity.is_zero_approx():
		return

	var new_lateral_velocity := lateral_velocity.move_toward(
		Vector3.ZERO,
		motion.ground_lateral_friction * state.step,
	)

	state.linear_velocity += (new_lateral_velocity - lateral_velocity)

# =========================================================================
# Floor detection
# =========================================================================


static func _find_floor_contact(state: PhysicsDirectBodyState3D, motion: C_Motion) -> int:
	var minimum_floor_dot := cos(deg_to_rad(motion.floor_max_angle_degrees))

	var best_contact_index: int = -1
	var best_floor_dot: float = minimum_floor_dot

	for contact_index in state.get_contact_count():
		var normal := state.get_contact_local_normal(contact_index)

		if normal.length_squared() <= INPUT_EPSILON:
			continue

		normal = normal.normalized()

		var floor_dot := normal.dot(Vector3.UP)

		if floor_dot < best_floor_dot:
			continue

		best_floor_dot = floor_dot
		best_contact_index = contact_index

	return best_contact_index


static func _update_floor_state(
	state: PhysicsDirectBodyState3D,
	motion: C_Motion,
	floor_contact_index: int,
) -> void:
	if floor_contact_index < 0:
		motion.is_on_floor = false
		motion.floor_normal = Vector3.UP
		motion.floor_velocity = Vector3.ZERO
		motion.floor_friction = DEFAULT_FRICTION

		return

	motion.is_on_floor = true

	motion.floor_normal = (state.get_contact_local_normal(floor_contact_index).normalized())

	motion.floor_velocity = (state.get_contact_collider_velocity_at_position(floor_contact_index))

	var collider := state.get_contact_collider_object(floor_contact_index)

	motion.floor_friction = _get_surface_traction(collider)

# =========================================================================
# Physics Material
# =========================================================================


## Character contact friction is zero to avoid sticking to walls/ceilings.
## Locomotion traction comes only from the floor, independently of that material.
static func _get_surface_traction(collider: Object) -> float:
	var surface_material: PhysicsMaterial = _get_physics_material(collider)
	return surface_material.friction if surface_material != null else DEFAULT_FRICTION


static func _get_physics_material(collider: Object) -> PhysicsMaterial:
	if collider == null:
		return null

	# Так мы не привязываем locomotion к конкретному
	# StaticBody3D/RigidBody3D.
	#
	# Любое тело с physics_material_override будет работать.
	var value := collider.get(&"physics_material_override") as PhysicsMaterial

	if value:
		return value

	return null

# =========================================================================
# Gameplay impulses
# =========================================================================


static func _apply_pending_impulse(state: PhysicsDirectBodyState3D, motion: C_Motion) -> void:
	if motion.pending_impulse.is_zero_approx():
		return

	state.apply_central_impulse(motion.pending_impulse)

	motion.pending_impulse = Vector3.ZERO


## Carry slowdown is derived from actual body mass and current Strength every physics tick.
static func effective_speed(
	motion: C_Motion,
	carry_load: C_CarryLoad,
	strength: C_Strength,
) -> float:
	if carry_load == null or not carry_load.active:
		return motion.max_speed
	return motion.max_speed * CarryLoadPolicy.active_multiplier(carry_load, strength)
