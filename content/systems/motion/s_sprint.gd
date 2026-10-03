extends System
## Проверяет намерение бега, расход/отдых и отдаёт множитель штатному физическому solver.
class_name S_Sprint

const MINIMUM_RUN_SPEED: float = 0.01
const MINIMUM_CAPACITY: float = 1.0
const EMPTY_EPSILON: float = 0.000001


func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_PlayerIntent]}


func query() -> QueryBuilder:
	return q.with_all([C_Stamina, C_Controller, C_Motion, C_Strength]).iterate([C_Stamina, C_Controller, C_Motion, C_Strength])


func _notification(what: int) -> void:
	if what != NOTIFICATION_PAUSED or not is_instance_valid(ECS.world):
		return
	for actor: Entity in ECS.world.query.with_all([C_Stamina, C_Motion]).execute():
		var stamina: C_Stamina = actor.get_component(C_Stamina) as C_Stamina
		stamina.toggled = false
		stamina.running = false
		(actor.get_component(C_Motion) as C_Motion).sprint_multiplier = 1.0


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	if delta <= 0.0:
		return
	var reserves: Array = components[0]
	var controllers: Array = components[1]
	var motions: Array = components[2]
	var strengths: Array = components[3]
	for index: int in entities.size():
		var actor: Entity = entities[index]
		var stamina: C_Stamina = reserves[index]
		var controller: C_Controller = controllers[index]
		var motion: C_Motion = motions[index]
		var strength: C_Strength = strengths[index]
		var strength_value: float = maxf(strength.value, 0.0) if is_finite(strength.value) else 0.0
		stamina.maximum = maxf(stamina.base_capacity + stamina.capacity_per_strength * strength_value, MINIMUM_CAPACITY)
		if not stamina.initialized:
			stamina.current = stamina.maximum
			stamina.initialized = true
		stamina.current = clampf(stamina.current, 0.0, stamina.maximum)
		var toggle_mode: bool = bool(GameSettingsService.value("sprint_toggle"))
		if stamina.toggle_mode != toggle_mode:
			stamina.toggled = false
		stamina.toggle_mode = toggle_mode
		var crouch: C_Crouch = actor.get_component(C_Crouch) as C_Crouch
		var allowed: bool = controller.sprint_input_enabled and motion.control_enabled and not actor.has_component(C_Death)
		allowed = allowed and not controller.action_crouch and (crouch == null or not crouch.active)
		allowed = allowed and InteractionControlFocus.current(actor) < InteractionControlFocus.Priority.PUSH
		if not allowed:
			stamina.toggled = false
		elif toggle_mode and controller.sprint_pressed:
			stamina.toggled = not stamina.toggled
		if stamina.exhausted and stamina.current >= stamina.maximum * stamina.restart_ratio:
			stamina.exhausted = false
		var carry: C_CarryLoad = actor.get_component(C_CarryLoad) as C_CarryLoad
		stamina.drain_multiplier = 1.0
		if carry != null and carry.active:
			var weight_fraction: float = clampf(carry.mass_kg / CarryLoadPolicy.maximum_mass_kg(strength), 0.0, 1.0)
			stamina.drain_multiplier = lerpf(stamina.minimum_carry_drain, stamina.maximum_carry_drain, weight_fraction)
		var requested: bool = stamina.toggled if toggle_mode else controller.sprint_held
		var can_run: bool = allowed and requested and not stamina.exhausted and stamina.current > 0.0
		can_run = can_run and motion.is_on_floor and not controller.direction_motion.is_zero_approx()
		can_run = can_run and CarryLoadPolicy.active_multiplier(carry, strength) > 0.0
		# Усиление разрешено с нулевой скорости для старта; расход — только при реальном движении.
		motion.sprint_multiplier = stamina.sprint_speed_multiplier if can_run else 1.0
		var velocity: Vector3 = Vector3.ZERO
		var character_body: CharacterBody3D = actor as Node as CharacterBody3D
		var rigid_body: RigidBody3D = actor as Node as RigidBody3D
		if character_body != null:
			velocity = character_body.velocity - motion.floor_velocity
		elif rigid_body != null:
			velocity = rigid_body.linear_velocity - motion.floor_velocity
		stamina.running = can_run and Vector2(velocity.x, velocity.z).length() >= MINIMUM_RUN_SPEED
		if stamina.running:
			stamina.current = maxf(stamina.current - stamina.drain_per_second * stamina.drain_multiplier * delta, 0.0)
			stamina.recovery_remaining = stamina.recovery_delay_seconds
			if stamina.current <= EMPTY_EPSILON:
				stamina.current = 0.0
				stamina.running = false
				stamina.exhausted = true
				stamina.toggled = false
				motion.sprint_multiplier = 1.0
		elif not actor.has_component(C_Death):
			var recovery_delta: float = maxf(delta - stamina.recovery_remaining, 0.0)
			stamina.recovery_remaining = maxf(stamina.recovery_remaining - delta, 0.0)
			stamina.current = minf(stamina.current + stamina.recovery_per_second * recovery_delta, stamina.maximum)
