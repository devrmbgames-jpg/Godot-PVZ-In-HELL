extends RefCounted
## Владеет принятием и исполнением подбора; отдельные owners читают состояние и освобождают хват.
class_name GrabService





#region Команды хвата и физическое исполнение
## Проверяет всю транзакцию до освобождения предмета из занятой руки.
static func can_pickup(
	holder: Entity,
	target: Entity,
	slot_index: int,
	replace: bool = false,
) -> bool:
	if not GrabQueries.entity_available(target):
		return false

	var body: RigidBody3D = GrabQueries.physical_body(target)
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
	if not GrabQueries.holder_available(holder) or not is_instance_valid(body):
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
		if not GrabQueries.entity_available(resolved_handle) or GrabQueries.held_relationship(resolved_handle) != null:
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

	var profile: GrabControlProfile = GrabQueries.profile_for(resolved_handle)
	if not GrabQueries.profile_slot_allowed(profile, slot_index):
		return false

	var strength: C_Strength = holder.get_component(C_Strength) as C_Strength
	if slot_index == C_Grabbable.HoldSlot.CARRY and not GrabQueries.can_carry_body(body, strength):
		return false
	if not is_instance_valid(GrabQueries.slot_anchor(holder, slot_index)):
		return false
	if GrabQueries.held_in_slot(holder, slot_index) != null and not replace:
		return false
	if storage_binding != null:
		var stored: R_StoredIn = storage_binding.relation as R_StoredIn
		var storage_slot: E_PhysicalSlot = storage_binding.target as E_PhysicalSlot
		return (
			stored != null and stored.applied and stored.snapshot != null
			and slot_index != C_Grabbable.HoldSlot.CARRY
			and PhysicalSlotService.can_use(holder, storage_slot)
		)
	return GrabReachQueries.within_pickup_reach_body(holder, body)


## Проверяет и занимает выбранный слот одной транзакцией; replace разрешает заменить его предмет.
static func try_pickup(
	holder: Entity,
	target: Entity,
	slot_index: int = -1,
	replace: bool = false,
) -> bool:
	if not GrabQueries.entity_available(target):
		return false

	var body: RigidBody3D = GrabQueries.physical_body(target)
	if body == null:
		return false
	if slot_index < 0:
		slot_index = GrabQueries.pickup_slot_for_body(holder, body, false)
	if not can_pickup(holder, target, slot_index, replace):
		return false
	return _acquire_validated(holder, target, slot_index)


## Проверяет луч по слоту хранения: у закреплённого предмета столкновения отключены.
static func can_take_from_storage(holder: Entity, target: Entity, slot_index: int, replace: bool = false) -> bool:
	var binding: Relationship = PhysicalSlotService.relationship(target)
	if binding == null:
		return false
	return can_pickup_body(holder, GrabQueries.physical_body(target), slot_index, replace, target, binding)


## Повторно проверяет перенос из слота, освобождает прежний предмет руки и приобретает хват.
static func take_from_storage(holder: Entity, target: Entity, slot_index: int, replace: bool = false) -> bool:
	if not can_take_from_storage(holder, target, slot_index, replace):
		return false

	PhysicalSlotService.release(target)
	return _acquire_validated(holder, target, slot_index)


static func _acquire_validated(holder: Entity, target: Entity, slot_index: int) -> bool:
	var body: RigidBody3D = GrabQueries.physical_body(target)

	ThrowContext.cancel(target)
	CartCargoService.release(target)
	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var anchor: Node3D = GrabQueries.slot_anchor(holder, slot_index)
	var profile: GrabControlProfile = GrabQueries.profile_for(target)
	var grip_data: R_HeldBy = R_HeldBy.new()
	grip_data.slot = slot_index as C_Grabbable.HoldSlot
	grip_data.profile = profile
	if slot_index == C_Grabbable.HoldSlot.CARRY:
		grip_data.hold_distance = GrabQueries.carry_distance_profile(control, profile)
	if not profile.reset_rotation_on_pickup:
		grip_data.rotation_offset = (
			anchor.global_basis.orthonormalized().get_rotation_quaternion().inverse()
			* body.global_basis.orthonormalized().get_rotation_quaternion()
		).normalized()

	var occupant: Entity = GrabQueries.held_in_slot(holder, slot_index)
	if occupant != null:
		GrabReleaseService.release(holder, occupant)
	target.add_relationship(Relationship.new(grip_data, holder))
	return GrabQueries.held_in_slot(holder, slot_index) == target


## Создаёт лёгкий прокси GECS только при фактическом подборе обычного физического тела.
static func try_pickup_body(
	holder: Entity,
	body: RigidBody3D,
	slot_index: int = -1,
	replace: bool = false,
) -> bool:
	if slot_index < 0:
		slot_index = GrabQueries.pickup_slot_for_body(holder, body, false)

	var existing: Entity = PhysicsGrabTarget.handle_for(body, false)
	if not can_pickup_body(holder, body, slot_index, replace, existing):
		return false

	var handle: Entity = PhysicsGrabTarget.handle_for(body, true)
	if handle == null:
		return false
	return try_pickup(holder, handle, slot_index, replace)


## Освобождает соответствующее владение перед импульсом авторского изменения скорости броска.
static func throw(holder: Entity, held: Entity) -> void:
	if not is_instance_valid(holder) or not is_instance_valid(held):
		return

	var grip: Relationship = GrabQueries.held_relationship(held)
	if grip == null or grip.target != holder:
		return

	var controller: C_Controller = holder.get_component(C_Controller) as C_Controller
	var body: RigidBody3D = GrabQueries.physical_body(held)
	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	var profile: GrabControlProfile = grip_data.profile

	if controller == null or body == null or profile == null:
		GrabReleaseService.release(holder, held)
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

	GrabReleaseService.release(holder, held)
	body.sleeping = false
	body.apply_central_impulse(impulse)
	if not impulse.is_zero_approx():
		ThrowContext.arm(held, holder)


#endregion


#region Жизненный цикл связей
## Обновляет производный вес переноски по действующему владению, не меняя захват.
static func refresh_carry_mass(held: Entity) -> void:
	var grip: Relationship = GrabQueries.held_relationship(held)
	var body: RigidBody3D = GrabQueries.physical_body(held)
	if grip == null or body == null:
		return

	var data: R_HeldBy = grip.relation as R_HeldBy
	if not data.lifecycle_applied or data.slot != C_Grabbable.HoldSlot.CARRY:
		return

	var holder: Entity = grip.target as Entity
	if not GrabQueries.holder_available(holder):
		return

	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if load_state != null:
		load_state.mass_kg = body.mass


## Применяет эффекты новой связи через O_GrabLifecycle независимо от создателя R_HeldBy.
static func grip_added(held: Entity, grip: Relationship) -> bool:
	var holder: Entity = grip.target as Entity
	var body: RigidBody3D = GrabQueries.physical_body(held)
	var grip_data: R_HeldBy = grip.relation as R_HeldBy
	if grip_data.profile == null:
		grip_data.profile = GrabQueries.profile_for(held)
	var profile: GrabControlProfile = grip_data.profile
	var is_invalid: bool = (
		not GrabQueries.holder_available(holder) or not GrabQueries.entity_available(held) or body == null
		or PhysicalSlotService.relationship(held) != null
		or body.freeze or profile == null or not is_instance_valid(GrabQueries.object_anchor(holder, held))
	)
	if is_invalid:
		return false

	var control: C_GrabControl = holder.get_component(C_GrabControl) as C_GrabControl
	var load_state: C_CarryLoad = holder.get_component(C_CarryLoad) as C_CarryLoad
	if control == null or load_state == null:
		return false

	var strength: C_Strength = holder.get_component(C_Strength) as C_Strength
	if grip_data.slot == C_Grabbable.HoldSlot.CARRY and not GrabQueries.can_carry_body(body, strength):
		return false
	if (
		GrabQueries.held_relationship(held) != grip or not GrabQueries.profile_slot_allowed(profile, grip_data.slot)
		or GrabQueries.held_in_slot(holder, grip_data.slot) != null
	):
		return false

	grip_data.lifecycle_applied = true
	if grip_data.slot == C_Grabbable.HoldSlot.CARRY and grip_data.hold_distance <= 0.0:
		grip_data.hold_distance = GrabQueries.carry_distance_profile(control, profile)
	grip_data.previous_can_sleep = body.can_sleep

	body.can_sleep = false
	body.sleeping = false

	var holder_body: PhysicsBody3D = holder as Node as PhysicsBody3D
	if holder_body != null and not body.get_collision_exceptions().has(holder_body):
		body.add_collision_exception_with(holder_body)
		grip_data.added_collision_exception = true

	GrabHoldCache.set_cached(control, grip_data.slot, held)
	if grip_data.slot == C_Grabbable.HoldSlot.CARRY:
		grip_data.capture_token = InteractionControlFocus.acquire(
			holder,
			held,
			InteractionControlFocus.Priority.CARRY,
		)
		load_state.active = true
		load_state.mass_kg = body.mass

	var cleanup: Callable = GrabReleaseService.release.bind(holder, held, false)
	if not held.tree_exiting.is_connected(cleanup):
		held.tree_exiting.connect(cleanup)
	if not holder.tree_exiting.is_connected(cleanup):
		holder.tree_exiting.connect(cleanup)

	if held.has_component(C_Package):
		PlayerInteractionEvents.publish(holder, held, PlayerInteractionEvent.Kind.PARCEL_PICKED)
	return true


#endregion
