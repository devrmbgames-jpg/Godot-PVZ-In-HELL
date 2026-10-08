extends RefCounted
## Владеет транзакциями хвата, жизненным циклом связей, поиском слотов и физическими адаптерами.
class_name GrabService

#region Общие ограничения
const NO_CARRY_GROUP: StringName = &"no_carry"
#endregion




#region Команды хвата и физическое исполнение
## Проверяет всю транзакцию до освобождения предмета из занятой руки.
static func can_pickup(
	holder: Entity,
	target: Entity,
	slot_index: int,
	replace: bool = false,
) -> bool:
	if not entity_available(target):
		return false

	var body: RigidBody3D = physical_body(target)
	return can_pickup_body(holder, body, slot_index, replace, target)


## Проверяет произвольное физическое тело; регистрация самого RigidBody3D в GECS необязательна.
static func can_pickup_body(
	holder: Entity,
	body: RigidBody3D,
	slot_index: int,
	replace: bool = false,
	handle: Entity = null,
	storage_binding: Relationship = null,
) -> bool:
	if not holder_available(holder) or not is_instance_valid(body):
		return false
	if body == (holder as Node as RigidBody3D) or slot_index < 0:
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if control == null or load_state == null or (body.freeze and storage_binding == null):
		return false

	var resolved_handle: Entity = handle
	if resolved_handle == null:
		resolved_handle = PhysicsGrabTarget.handle_for(body, false)
	if resolved_handle != null:
		if not entity_available(resolved_handle) or held_relationship(resolved_handle) != null:
			return false
		if CustomerInspectionQueries.owner_for(resolved_handle) != null:
			return false
		# Физическое тело не обязательно является предметом; живого персонажа нельзя переносить.
		if resolved_handle.has_component(C_Living) and not resolved_handle.has_component(C_Death):
			return false
		if PhysicalSlotService.relationship(resolved_handle) != storage_binding:
			return false

		var interactable: C_Interactable = (
			resolved_handle.get_component(C_Interactable) as C_Interactable
		)
		if interactable != null and not interactable.enabled:
			return false

	var profile: GrabControlProfile = profile_for(resolved_handle)
	if not profile_slot_allowed(profile, slot_index):
		return false

	var strength: C_Strength = holder.get_component(C_Strength) as C_Strength
	if slot_index == C_Grabbable.HoldSlot.CARRY and not can_carry_body(body, strength):
		return false
	if not is_instance_valid(slot_anchor(holder, slot_index)):
		return false
	if held_in_slot(holder, slot_index) != null and not replace:
		return false
	if storage_binding != null:
		var stored: R_StoredIn = storage_binding.relation as R_StoredIn
		var storage_slot: E_PhysicalSlot = storage_binding.target as E_PhysicalSlot
		return (
			stored != null and stored.applied and stored.snapshot != null
			and slot_index != C_Grabbable.HoldSlot.CARRY
			and PhysicalSlotService.can_use(holder, storage_slot)
		)
	return within_pickup_reach_body(holder, body)


## Проверяет и занимает выбранный слот одной транзакцией; replace разрешает заменить его предмет.
static func try_pickup(
	holder: Entity,
	target: Entity,
	slot_index: int = -1,
	replace: bool = false,
) -> bool:
	if not entity_available(target):
		return false

	var body: RigidBody3D = physical_body(target)
	if body == null:
		return false
	if slot_index < 0:
		slot_index = pickup_slot_for_body(holder, body, false)
	if not can_pickup(holder, target, slot_index, replace):
		return false
	return _acquire_validated(holder, target, slot_index)


## Проверяет луч по слоту хранения: у закреплённого предмета столкновения отключены.
static func can_take_from_storage(holder: Entity, target: Entity, slot_index: int, replace: bool = false) -> bool:
	var binding: Relationship = PhysicalSlotService.relationship(target)
	if binding == null:
		return false
	return can_pickup_body(holder, physical_body(target), slot_index, replace, target, binding)


## Повторно проверяет перенос из слота, освобождает прежний предмет руки и приобретает хват.
static func take_from_storage(holder: Entity, target: Entity, slot_index: int, replace: bool = false) -> bool:
	if not can_take_from_storage(holder, target, slot_index, replace):
		return false

	PhysicalSlotService.release(target)
	return _acquire_validated(holder, target, slot_index)


static func _acquire_validated(holder: Entity, target: Entity, slot_index: int) -> bool:
	var body: RigidBody3D = physical_body(target)

	ThrowContext.cancel(target)
	CartCargoService.release(target)
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var anchor: Node3D = slot_anchor(holder, slot_index)
	var profile: GrabControlProfile = profile_for(target)
	var grip_data: R_HeldBy = R_HeldBy.new()
	grip_data.slot = slot_index as C_Grabbable.HoldSlot
	grip_data.profile = profile
	if slot_index == C_Grabbable.HoldSlot.CARRY:
		grip_data.hold_distance = carry_distance_profile(control, profile)
	if not profile.reset_rotation_on_pickup:
		grip_data.rotation_offset = (
			anchor.global_basis.orthonormalized().get_rotation_quaternion().inverse()
			* body.global_basis.orthonormalized().get_rotation_quaternion()
		).normalized()

	var occupant: Entity = held_in_slot(holder, slot_index)
	if occupant != null:
		release(holder, occupant)
	target.add_relationship(Relationship.new(grip_data, holder))
	return held_in_slot(holder, slot_index) == target


## Создаёт лёгкий прокси GECS только при фактическом подборе обычного физического тела.
static func try_pickup_body(
	holder: Entity,
	body: RigidBody3D,
	slot_index: int = -1,
	replace: bool = false,
) -> bool:
	if slot_index < 0:
		slot_index = pickup_slot_for_body(holder, body, false)

	var existing: Entity = PhysicsGrabTarget.handle_for(body, false)
	if not can_pickup_body(holder, body, slot_index, replace, existing):
		return false

	var handle: Entity = PhysicsGrabTarget.handle_for(body, true)
	if handle == null:
		return false
	return try_pickup(holder, handle, slot_index, replace)


## Удаляет соответствующую связь и её эффекты, сохраняя физическую инерцию тела.
static func release(holder: Entity, held: Entity, notify_player: bool = true) -> void:
	if not is_instance_valid(held):
		return

	var grip: Relationship = held_relationship(held)
	if grip != null and grip.target == holder:
		var grip_data: R_HeldBy = grip.relation as R_HeldBy
		var notify: bool = notify_player and grip_data.lifecycle_applied and holder_available(holder) and entity_available(held)
		held.remove_relationship(grip)
		# World отключает сигналы сущности до уведомления наблюдателей жизненного цикла.
		# Идемпотентная очистка покрывает и этот путь удаления.
		grip_removed(held, grip)
		if notify and held.has_component(C_Package):
			PlayerInteractionEvents.publish(holder, held, PlayerInteractionEvent.Kind.PARCEL_PLACED)


## Освобождает соответствующее владение перед импульсом авторского изменения скорости броска.
static func throw(holder: Entity, held: Entity) -> void:
	if not is_instance_valid(holder) or not is_instance_valid(held):
		return

	var grip: Relationship = held_relationship(held)
	if grip == null or grip.target != holder:
		return

	var controller: C_Controller = holder.get_component(C_Controller) as C_Controller
	var body: RigidBody3D = physical_body(held)
	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	var profile: GrabControlProfile = grip_data.profile

	if controller == null or body == null or profile == null:
		release(holder, held)
		return

	var carry_load: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	var strength: C_Strength = holder.get_component(C_Strength) as C_Strength
	var effective_throw_velocity: float = CarryLoadPolicy.scaled_value(
		profile.throw_velocity,
		carry_load,
		strength,
	)
	var impulse: Vector3 = GrabPhysicsSolver.throw_impulse(
		controller.direction_look,
		effective_throw_velocity,
		body.mass,
	)

	release(holder, held)
	body.sleeping = false
	body.apply_central_impulse(impulse)
	if not impulse.is_zero_approx():
		ThrowContext.arm(held, holder)


#endregion


#region Жизненный цикл связей
## Обновляет производный вес переноски по действующему владению, не меняя захват.
static func refresh_carry_mass(held: Entity) -> void:
	var grip: Relationship = held_relationship(held)
	var body: RigidBody3D = physical_body(held)
	if grip == null or body == null:
		return

	var data: R_HeldBy = grip.relation as R_HeldBy
	if not data.lifecycle_applied or data.slot != C_Grabbable.HoldSlot.CARRY:
		return

	var holder: Entity = grip.target as Entity
	if not holder_available(holder):
		return

	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if load_state != null:
		load_state.mass_kg = body.mass


## Применяет эффекты новой связи через O_GrabLifecycle независимо от создателя R_HeldBy.
static func grip_added(held: Entity, grip: Relationship) -> bool:
	var holder: Entity = grip.target as Entity
	var body: RigidBody3D = physical_body(held)
	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	if grip_data.profile == null:
		grip_data.profile = profile_for(held)
	var profile: GrabControlProfile = grip_data.profile
	var is_invalid: bool = (
		not holder_available(holder) or not entity_available(held) or body == null
		or PhysicalSlotService.relationship(held) != null
		or body.freeze or profile == null or not is_instance_valid(object_anchor(holder, held))
	)
	if is_invalid:
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if control == null or load_state == null:
		return false

	var strength: C_Strength = holder.get_component(C_Strength) as C_Strength
	if grip_data.slot == C_Grabbable.HoldSlot.CARRY and not can_carry_body(body, strength):
		return false
	if (
		held_relationship(held) != grip or not profile_slot_allowed(profile, grip_data.slot)
		or held_in_slot(holder, grip_data.slot) != null
	):
		return false

	grip_data.lifecycle_applied = true
	if grip_data.slot == C_Grabbable.HoldSlot.CARRY and grip_data.hold_distance <= 0.0:
		grip_data.hold_distance = carry_distance_profile(control, profile)
	grip_data.previous_can_sleep = body.can_sleep

	body.can_sleep = false
	body.sleeping = false

	var holder_body: PhysicsBody3D = holder as Node as PhysicsBody3D
	if holder_body != null and not body.get_collision_exceptions().has(holder_body):
		body.add_collision_exception_with(holder_body)
		grip_data.added_collision_exception = true

	_set_cached(control, grip_data.slot, held)
	if grip_data.slot == C_Grabbable.HoldSlot.CARRY:
		grip_data.capture_token = InteractionControlFocus.acquire(
			holder,
			held,
			InteractionControlFocus.Priority.CARRY,
		)
		load_state.active = true
		load_state.mass_kg = body.mass

	var cleanup: Callable = release.bind(holder, held, false)
	if not held.tree_exiting.is_connected(cleanup):
		held.tree_exiting.connect(cleanup)
	if not holder.tree_exiting.is_connected(cleanup):
		holder.tree_exiting.connect(cleanup)

	if held.has_component(C_Package):
		PlayerInteractionEvents.publish(holder, held, PlayerInteractionEvent.Kind.PARCEL_PICKED)
	return true


## Однократно восстанавливает столкновения и сон, освобождает захват и кеш слота.
static func grip_removed(held: Entity, grip: Relationship) -> void:
	var marker: C_Marker = held.get_component(C_Marker) as C_Marker
	if marker != null:
		MarkerSessionService.end(held, grip.target as Entity)

	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	if not grip_data.lifecycle_applied:
		return

	grip_data.lifecycle_applied = false
	if is_instance_valid(held) and held.has_component(C_MeleeWeapon):
		MeleeWeaponPresentation.reset(held)
	var holder: Entity = grip.target as Entity if is_instance_valid(grip.target) else null
	var body: RigidBody3D = physical_body(held)
	if is_instance_valid(holder):
		InteractionControlFocus.release(holder, grip_data.capture_token)
		var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
		if control != null and _cached(control, grip_data.slot) == held:
			reset_holder(holder, grip_data.slot)

	var cleanup: Callable = release.bind(holder, held, false)
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


## Освобождает все входящие и исходящие связи удержания недоступной сущности.
static func entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return

	var grip: Relationship = held_relationship(entity)
	if grip != null:
		entity.remove_relationship(grip)
		grip_removed(entity, grip)

	for slot_index: int in 3:
		var held: Entity = held_in_slot(entity, slot_index)
		if held != null:
			release(entity, held, false)


## Очищает производный кеш слота и модификаторы Carry, не создавая владение.
static func reset_holder(holder: Entity, slot_index: int = C_Grabbable.HoldSlot.CARRY) -> void:
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	if control != null:
		var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
		if interactor != null and interactor.target == _cached(control, slot_index):
			interactor.target = null
		_set_cached(control, slot_index, null)
		control.rotation_active = false

	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if load_state != null and slot_index == C_Grabbable.HoldSlot.CARRY:
		load_state.active = false
		load_state.mass_kg = 0.0

#endregion


#region Поиск и проверки
## Читает авторитетную связь удержания непосредственно у предмета.
static func held_relationship(entity: Entity) -> Relationship:
	if not is_instance_valid(entity):
		return null

	# Читаем авторитетные локальные связи без выделения шаблонов запроса.
	for grip: Relationship in entity.relationships:
		if grip.relation is R_HeldBy:
			return grip

	return null


## Совместимый поиск одного предмета; вместимость и владение проверяются по отдельным слотам.
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

	var held: Entity = _cached(control, slot_index)
	if is_instance_valid(held):
		var grip: Relationship = held_relationship(held)
		if grip != null and grip.target == holder:
			if (grip.relation as R_HeldBy).slot == slot_index:
				return held
	if held != null:
		reset_holder(holder, slot_index)
	return null


static func _cached(control: C_GrabControl, slot_index: int) -> Entity:
	match slot_index:
		C_Grabbable.HoldSlot.CARRY:
			return control.held_carry

		C_Grabbable.HoldSlot.RIGHT_HAND:
			return control.held_right

		C_Grabbable.HoldSlot.LEFT_HAND:
			return control.held_left
	return null


static func _set_cached(control: C_GrabControl, slot_index: int, held: Entity) -> void:
	match slot_index:
		C_Grabbable.HoldSlot.CARRY:
			control.held_carry = held
		C_Grabbable.HoldSlot.RIGHT_HAND:
			control.held_right = held
		C_Grabbable.HoldSlot.LEFT_HAND:
			control.held_left = held


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


## Повторно проверяет первое попадание луча и общий предел дистанции взаимодействия.
## Игровая цель может быть CharacterBody3D или AnimatableBody3D; только обычный Carry
## требует RigidBody3D и проверяется через within_pickup_reach_body().
static func within_pickup_reach(holder: Entity, target: Entity) -> bool:
	if not entity_available(target):
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	var raycast: RayCast3D = interaction_raycast(holder)
	if control == null or interactor == null or not is_instance_valid(raycast):
		return false
	if InteractionTargetingGeometry.find_target(holder, interactor) != target:
		return false
	if not raycast.is_colliding():
		return false

	var hit_distance: float = raycast.global_position.distance_to(raycast.get_collision_point())
	return hit_distance <= maxf(control.pickup_distance, 0.0)


## Повторно проверяет первое физическое тело под лучом и дистанцию подбора.
static func within_pickup_reach_body(holder: Entity, body: RigidBody3D) -> bool:
	if not is_instance_valid(holder) or not is_instance_valid(body):
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var interactor: C_Interactor = holder.get_component(C_Interactor) as C_Interactor
	var raycast: RayCast3D = interaction_raycast(holder)
	if control == null or interactor == null or not is_instance_valid(raycast):
		return false
	if InteractionTargetingGeometry.find_physics_target(holder, interactor) != body:
		return false
	if not raycast.is_colliding():
		return false

	var hit_distance: float = raycast.global_position.distance_to(raycast.get_collision_point())
	return hit_distance <= maxf(control.pickup_distance, 0.0)


## Возвращает дистанцию Carry в метрах: настройку предмета либо держателя; руки без добавочного отступа.
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
