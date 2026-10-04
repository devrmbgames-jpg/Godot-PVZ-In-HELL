extends RefCounted
## Выполняет переносы слота на границе команды resolver, отдельно от физического solver.
class_name PhysicalSlotService


#region Проверка и перенос в слот
## Читает авторитетную связь R_StoredIn предмета.
static func relationship(item: Entity) -> Relationship:
	if is_instance_valid(item):
		for binding: Relationship in item.relationships:
			if binding.relation is R_StoredIn:
				return binding
	return null


## Возвращает единственный предмет, связанный с физическим слотом.
static func occupant(slot: Entity) -> Entity:
	if not is_instance_valid(ECS.world):
		return null

	for item: Entity in ECS.world.query.with_relationship([Relationship.new(R_StoredIn.new(), slot)]).execute():
		return item
	return null


## Проверяет доступного актора, слот и дистанцию взаимодействия.
static func can_use(actor: Entity, slot: E_PhysicalSlot) -> bool:
	return (
		GrabService.holder_available(actor) and GrabService.entity_available(slot)
		and slot.has_component(C_PhysicalSlot) and is_instance_valid(slot.anchor)
		and is_instance_valid(slot.driver)
		and InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.HANDS
		and GrabService.within_pickup_reach(actor, slot)
	)


## Проверяет предмет выбранной руки, свободный слот, фильтр и массу.
static func can_store(actor: Entity, slot: E_PhysicalSlot, hand: int) -> bool:
	if not can_use(actor, slot) or occupant(slot) != null:
		return false
	if hand != C_Grabbable.HoldSlot.LEFT_HAND and hand != C_Grabbable.HoldSlot.RIGHT_HAND:
		return false

	var item: Entity = GrabService.held_in_slot(actor, hand)
	if not GrabService.entity_available(item) or relationship(item) != null:
		return false

	var body: RigidBody3D = GrabService.physical_body(item)
	# Физический слот хранит реальную Entity мира, а не прокси тела без скрипта.
	if body == null or (body as Node) != (item as Node) or body.freeze:
		return false
	if item == slot or item.is_ancestor_of(slot) or CartCargoService.relationship(item) != null:
		return false

	var config: C_PhysicalSlot = slot.get_component(C_PhysicalSlot) as C_PhysicalSlot
	if body.mass > config.maximum_mass:
		return false
	return config.filter == null or ItemAccessService.matches(item.get_component(C_AccessItem) as C_AccessItem, config.filter)


## После проверки освобождает руку, создаёт R_StoredIn и применяет крепление.
static func store(actor: Entity, slot: E_PhysicalSlot, hand: int) -> bool:
	if not can_store(actor, slot, hand):
		return false

	var item: Entity = GrabService.held_in_slot(actor, hand)
	GrabService.release(actor, item)
	ThrowContext.cancel(item)
	var binding: Relationship = Relationship.new(R_StoredIn.new(), slot)
	item.add_relationship(binding)
	if not attach(item, binding):
		item.remove_relationship(binding)
		return false
	return true


#endregion

#region Обратимое физическое крепление
## Применяет крепление однократно для прямого вызова и наблюдателя связи.
static func attach(item: Entity, binding: Relationship) -> bool:
	var data: R_StoredIn = binding.relation as R_StoredIn
	if data.applied:
		return true

	var slot: E_PhysicalSlot = binding.target as E_PhysicalSlot
	var body: RigidBody3D = GrabService.physical_body(item)
	if (
		not GrabService.entity_available(item) or not GrabService.entity_available(slot)
		or not is_instance_valid(slot.anchor) or not is_instance_valid(slot.driver)
		or body == null or body.freeze
		or not slot.has_component(C_PhysicalSlot) or relationship(item) != binding
		or GrabService.held_relationship(item) != null or CartCargoService.relationship(item) != null
		or (body as Node) != (item as Node) or item.is_ancestor_of(slot)
	):
		return false

	var config: C_PhysicalSlot = slot.get_component(C_PhysicalSlot) as C_PhysicalSlot
	if body.mass > config.maximum_mass or (
		config.filter != null and not ItemAccessService.matches(item.get_component(C_AccessItem) as C_AccessItem, config.filter)
	):
		return false

	for other: Entity in ECS.world.query.with_relationship([Relationship.new(R_StoredIn.new(), slot)]).execute():
		if other != item:
			return false

	var snapshot: StoredBodySnapshot = StoredBodySnapshot.new()
	snapshot.freeze = body.freeze
	snapshot.freeze_mode = body.freeze_mode
	snapshot.collision_layer = body.collision_layer
	snapshot.collision_mask = body.collision_mask
	snapshot.physics_processing = body.is_physics_processing()
	snapshot.top_level = body.top_level
	data.snapshot = snapshot
	data.applied = true
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.collision_layer = 0
	body.collision_mask = 0
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.set_physics_process(false)
	body.top_level = snapshot.top_level
	body.global_transform = slot.anchor.global_transform
	slot.driver.remote_path = slot.driver.get_path_to(body)
	slot.driver.use_global_coordinates = true
	slot.driver.update_position = true
	slot.driver.update_rotation = true
	slot.driver.update_scale = true
	slot.driver.force_update_cache()

	var cleanup: Callable = release.bind(item)
	slot.tree_exiting.connect(cleanup)
	item.tree_exiting.connect(cleanup)
	return true


## Освобождает связь хранения и восстанавливает физические настройки; повтор безопасен.
static func release(item: Entity) -> void:
	var binding: Relationship = relationship(item)
	if binding == null:
		return
	# Удаление связи обычно синхронно вызывает наблюдатель жизненного цикла.
	item.remove_relationship(binding)
	var data: R_StoredIn = binding.relation as R_StoredIn
	if data.applied:
		detach(item, binding)


## Однократно снимает RemoteTransform-крепление и возвращает настройки из снимка.
static func detach(item: Entity, binding: Relationship) -> void:
	var data: R_StoredIn = binding.relation as R_StoredIn
	if not data.applied:
		return

	data.applied = false
	var slot: Entity = binding.target as Entity
	var cleanup: Callable = release.bind(item)
	for participant: Entity in [item, slot]:
		if is_instance_valid(participant) and participant.tree_exiting.is_connected(cleanup):
			participant.tree_exiting.disconnect(cleanup)
	var body: RigidBody3D = GrabService.physical_body(item)
	if body == null:
		return

	var snapshot: StoredBodySnapshot = data.snapshot
	var storage_slot: E_PhysicalSlot = slot as E_PhysicalSlot
	if storage_slot != null and is_instance_valid(storage_slot.driver):
		storage_slot.driver.remote_path = NodePath()
	body.top_level = snapshot.top_level
	body.collision_layer = snapshot.collision_layer
	body.collision_mask = snapshot.collision_mask
	body.freeze_mode = snapshot.freeze_mode
	body.freeze = snapshot.freeze
	body.set_physics_process(snapshot.physics_processing)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false


#endregion

#region Недоступность и надетые предметы
## Освобождает предмет и входящие крепления недоступного слота.
static func entity_unavailable(entity: Entity) -> void:
	release(entity)
	var item: Entity = occupant(entity)
	if item != null:
		release(item)
	if is_instance_valid(ECS.world):
		for slot: Entity in ECS.world.query.with_relationship([Relationship.new(R_SlotMountedOn.new(), entity)]).execute():
			var stored: Entity = occupant(slot)
			if stored != null:
				release(stored)


## GECS удаляет сущности отдельно: перед освобождением носителя из World удаляются также
## его авторские дочерние слоты; независимые стойки остаются в мире.
static func entity_removed(entity: Entity) -> void:
	entity_unavailable(entity)
	if not is_instance_valid(ECS.world):
		return

	for candidate: Entity in ECS.world.entities.duplicate():
		if candidate is E_PhysicalSlot and entity.is_ancestor_of(candidate):
			ECS.world.remove_entity(candidate)


## Возвращает реальные предметы слотов, связанных с актором через R_SlotMountedOn.
static func worn_items(actor: Entity) -> Array[Entity]:
	var result: Array[Entity] = []
	if not GrabService.holder_available(actor):
		return result

	for slot: Entity in ECS.world.query.with_relationship([Relationship.new(R_SlotMountedOn.new(), actor)]).execute():
		if GrabService.entity_available(slot):
			var item: Entity = occupant(slot)
			if GrabService.entity_available(item):
				result.append(item)
	return result

#endregion
