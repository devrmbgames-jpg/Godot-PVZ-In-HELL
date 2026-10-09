extends RefCounted
## Читает живые связи хвата, доступность, авторские профили и физические точки без операций подбора.
class_name GrabQueries

## Группа тел, исключённых из обычной переноски.
const NO_CARRY_GROUP: StringName = &"no_carry"

#region Live grip and slot queries
## Читает авторитетную связь удержания непосредственно у предмета.
static func held_relationship(entity: Entity) -> Relationship:
	if not is_instance_valid(entity):
		return null

	# Читаем авторитетные локальные связи без выделения шаблонов запроса.
	for grip: Relationship in entity.relationships:
		if grip.relation is R_HeldBy:
			return grip

	return null


## Возвращает первый удерживаемый предмет по живым связям физических слотов.
static func held_object(holder: Entity) -> Entity:
	for slot_index: int in 3:
		var held: Entity = held_in_slot(holder, slot_index)
		if held != null:
			return held
	return null


## Возвращает кешированный предмет только при совпадении живой авторитетной связи со слотом.
static func held_in_slot(holder: Entity, slot_index: int) -> Entity:
	if not is_instance_valid(holder):
		return null

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	if control == null:
		return null

	var held: Entity = GrabHoldCache.cached(control, slot_index)
	if is_instance_valid(held):
		var grip: Relationship = held_relationship(held)
		if grip != null and grip.target == holder:
			if (grip.relation as R_HeldBy).slot == slot_index:
				return held
	if held != null:
		GrabHoldCache.reset_holder(holder, slot_index)
	return null


#endregion

#region Carry eligibility and hand selection
## Проверяет физический кандидат Carry без учёта текущего Strength держателя.
static func is_carry_candidate(body: RigidBody3D) -> bool:
	if not is_instance_valid(body) or body.is_queued_for_deletion():
		return false
	if not body.is_inside_tree() or body.freeze or body.is_in_group(NO_CARRY_GROUP):
		return false
	return is_finite(body.mass) and body.mass > 0.0


## Возвращает true, только если подходящее тело невозможно поднять именно из-за массы.
static func is_too_heavy(body: RigidBody3D, strength: C_Strength) -> bool:
	return (
		is_carry_candidate(body)
		and strength != null
		and not CarryLoadPolicy.can_carry(body.mass, strength)
	)


## Проверяет Carry для авторских и обычных физических тел по массе и Strength.
static func can_carry_body(body: RigidBody3D, strength: C_Strength) -> bool:
	return is_carry_candidate(body) and CarryLoadPolicy.can_carry(body.mass, strength)


## Проверяет поддержку запрошенного Carry либо физического ручного слота авторским предметом.
static func slot_allowed(config: C_Grabbable, slot_index: int) -> bool:
	return profile_slot_allowed(GrabControlProfile.from_grabbable(config), slot_index)


## Проверяет физический слот по фактическому профилю хвата.
static func profile_slot_allowed(profile: GrabControlProfile, slot_index: int) -> bool:
	if profile == null:
		return false
	if slot_index == C_Grabbable.HoldSlot.CARRY:
		return profile.allowed_hand_slots == 0
	return (
		slot_index in [C_Grabbable.HoldSlot.RIGHT_HAND, C_Grabbable.HoldSlot.LEFT_HAND]
		and (profile.allowed_hand_slots & (1 << slot_index)) != 0
	)


## Сопоставляет основной либо дополнительный ввод физической руке с учётом swap_hand_controls.
static func mapped_hand(holder: Entity, secondary: bool = false) -> int:
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	if secondary != (control != null and control.swap_hand_controls):
		return C_Grabbable.HoldSlot.LEFT_HAND
	return C_Grabbable.HoldSlot.RIGHT_HAND


## Выбирает руку E/F по свободным слотам, режиму замены и авторским ограничениям рук.
static func pickup_slot(holder: Entity, target: Entity, replacement_button: bool) -> int:
	if not is_instance_valid(target) or not is_instance_valid(holder):
		return -1

	var config: C_Grabbable = target.get_component(C_Grabbable) as C_Grabbable
	if config == null:
		return -1
	if config.allowed_hand_slots == 0:
		return C_Grabbable.HoldSlot.CARRY if not replacement_button else -1

	var primary: int = mapped_hand(holder)
	var secondary: int = mapped_hand(holder, true)
	var primary_busy: bool = held_in_slot(holder, primary) != null
	var secondary_busy: bool = held_in_slot(holder, secondary) != null
	var selected: int = primary
	if replacement_button:
		if not primary_busy and not secondary_busy:
			return -1

		selected = secondary if secondary_busy else primary
	else:
		selected = secondary if primary_busy and not secondary_busy else primary
		if not primary_busy and not secondary_busy and not slot_allowed(config, selected):
			selected = secondary
	return selected if slot_allowed(config, selected) else -1


## Обычные тела допускают только Carry; авторский C_Grabbable сохраняет правила ручных слотов.
static func pickup_slot_for_body(
	holder: Entity,
	body: RigidBody3D,
	replacement_button: bool,
) -> int:
	if not is_instance_valid(holder) or not is_instance_valid(body):
		return -1

	var handle: Entity = PhysicsGrabTarget.handle_for(body, false)
	if handle != null and (handle.get_component(C_Grabbable) as C_Grabbable) != null:
		return pickup_slot(holder, handle, replacement_button)
	return C_Grabbable.HoldSlot.CARRY if not replacement_button else -1


#endregion

#region Physical anchors and actor availability
## Возвращает луч держателя для наведения и повторной проверки подбора.
static func interaction_raycast(holder: Entity) -> RayCast3D:
	if not is_instance_valid(holder):
		return null

	return holder.get("interaction_ray_cast") as RayCast3D


## Возвращает авторскую точку Carry, принадлежащую сущности держателя.
static func hold_anchor(holder: Entity) -> Node3D:
	if not is_instance_valid(holder):
		return null

	return holder.get("hold_anchor") as Node3D


## Выбирает точку предмета по живой связи либо предполагаемому слоту подбора.
static func object_anchor(holder: Entity, target: Entity) -> Node3D:
	if not is_instance_valid(holder) or not is_instance_valid(target):
		return null

	var grip: Relationship = held_relationship(target)
	var slot_index: int = (
		(grip.relation as R_HeldBy).slot
		if grip != null
		else pickup_slot(holder, target, false)
	)
	return slot_anchor(holder, slot_index)


## Выбирает обычную либо подвешенную авторскую точку физического слота.
static func slot_anchor(holder: Entity, slot_index: int) -> Node3D:
	if not is_instance_valid(holder):
		return null
	if (
		slot_index != C_Grabbable.HoldSlot.CARRY
		and InteractionControlFocus.current(holder) != InteractionControlFocus.Priority.HANDS
	):
		var right_hand: bool = slot_index == C_Grabbable.HoldSlot.RIGHT_HAND
		var lowered: Node3D = holder.get(
			"lowered_right_hand_slot" if right_hand else "lowered_left_hand_slot"
		) as Node3D
		if is_instance_valid(lowered):
			return lowered

	match slot_index:
		C_Grabbable.HoldSlot.CARRY:
			return hold_anchor(holder)

		C_Grabbable.HoldSlot.RIGHT_HAND:
			return holder.get("right_hand_slot") as Node3D

		C_Grabbable.HoldSlot.LEFT_HAND:
			return holder.get("left_hand_slot") as Node3D
	return null


## Возвращает дистанцию Carry в метрах по предмету или держателю; руки без отступа.
static func carry_distance(control: C_GrabControl, config: C_Grabbable) -> float:
	return carry_distance_profile(control, GrabControlProfile.from_grabbable(config))


## Выбирает дистанцию Carry в метрах из фактического профиля либо настроек держателя.
static func carry_distance_profile(
	control: C_GrabControl,
	profile: GrabControlProfile,
) -> float:
	if control == null or profile == null:
		return 0.0
	if profile.allowed_hand_slots != 0:
		return 0.0
	if profile.hold_distance >= 0.0:
		return profile.hold_distance
	return control.hold_distance


## Возвращает физическое тело обычной Entity либо временного прокси.
static func physical_body(handle: Entity) -> RigidBody3D:
	return PhysicsGrabTarget.body_for(handle)


## Создаёт фактический профиль, включая удержание жидкости вертикально; C_Grabbable необязателен.
static func profile_for(handle: Entity) -> GrabControlProfile:
	var config: C_Grabbable = null
	var liquid: C_LiquidTilt = null
	if is_instance_valid(handle):
		config = handle.get_component(C_Grabbable) as C_Grabbable
		liquid = handle.get_component(C_LiquidTilt) as C_LiquidTilt
	var profile: GrabControlProfile = GrabControlProfile.from_grabbable(config)
	if liquid != null and liquid.keep_upright_while_held:
		profile.keep_upright = true
		profile.rotation_axis = C_Grabbable.RotationAxis.Y_ONLY
		profile.max_rotation_speed = minf(profile.max_rotation_speed, liquid.upright_rotation_speed)
	return profile


## Проверяет живое дерево, enabled и регистрацию в текущем World перед изменением игры.
static func entity_available(entity: Entity) -> bool:
	return (
		is_instance_valid(entity) and not entity.is_queued_for_deletion()
		and entity.is_inside_tree() and entity.enabled and is_instance_valid(ECS.world)
		and ECS.world.entity_to_archetype.has(entity)
	)


## Проверяет доступность держателя, управление движением и положительное здоровье.
static func holder_available(holder: Entity) -> bool:
	if not entity_available(holder):
		return false

	var motion: C_Motion = holder.get_component(C_Motion) as C_Motion
	var health: C_Health = holder.get_component(C_Health) as C_Health
	return (motion == null or motion.control_enabled) and (health == null or health.current > 0.0)
#endregion
