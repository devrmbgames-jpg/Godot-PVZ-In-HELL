extends RefCounted
## Whole-stack transfer contract for pickups, Trader, containers and loot.
## OwnedBy is sole live authority. Rejected effects never consume quantity.
class_name InventoryService

const USE_PREFIX: String = "inventory_use:"


static func owner_for(item: Entity) -> Entity:
	if not _registered(item):
		return null
	var owner: Entity = null
	var count: int = 0
	for link: Relationship in item.relationships:
		if link.relation is R_OwnedBy:
			count += 1
			owner = link.target as Entity
	return owner if count == 1 and _registered(owner) else null


static func items(owner: Entity) -> Array[Entity]:
	var result: Array[Entity] = []
	if not EntityAvailability.contains(owner, ECS.world) or not owner.has_component(C_Inventory):
		return result
	for item: Entity in ECS.world.query.with_all([C_InventoryItem]).execute():
		if owner_for(item) == owner:
			result.append(item)
	return result


static func item_by_id(owner: Entity, item_id: String) -> Entity:
	for item: Entity in items(owner):
		if item.id == item_id:
			return item
	return null


static func can_transfer(item: Entity, destination: Entity, expected_owner: Entity = null) -> bool:
	if not _owner_available(destination) or not EntityAvailability.contains(item, ECS.world) or item == destination or item.has_component(C_Package) or item.has_component(C_Grabbable):
		return false
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	if not _valid_item(state) or state.definition.kind == DEF_InventoryItem.Kind.FURNITURE or state.transfer_in_progress or not state.pending_use_id.is_empty():
		return false
	var ownership_count: int = 0
	for link: Relationship in item.relationships:
		if link.relation is R_OwnedBy:
			ownership_count += 1
	var previous: Entity = owner_for(item)
	if ownership_count > 1 or (ownership_count == 1 and previous == null) or previous != expected_owner or previous == destination:
		return false
	if previous != null and not _owner_available(previous):
		return false
	var destination_items: Array[Entity] = items(destination)
	var room: int = 0
	for existing: Entity in destination_items:
		var other: C_InventoryItem = existing.get_component(C_InventoryItem) as C_InventoryItem
		if _compatible(state, other) and other.pending_use_id.is_empty():
			room += maxi(0, other.definition.maximum_stack - other.quantity)
	var inventory: C_Inventory = destination.get_component(C_Inventory) as C_Inventory
	return room >= state.quantity or destination_items.size() < inventory.maximum_stacks


static func transfer(item: Entity, destination: Entity, expected_owner: Entity = null) -> bool:
	if not can_transfer(item, destination, expected_owner):
		return false
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	var destination_inventory: C_Inventory = destination.get_component(C_Inventory) as C_Inventory
	var previous_inventory: C_Inventory = expected_owner.get_component(C_Inventory) as C_Inventory if expected_owner != null else null
	destination_inventory.transfer_in_progress = true
	if previous_inventory != null:
		previous_inventory.transfer_in_progress = true
	state.transfer_in_progress = true
	for link: Relationship in item.relationships.duplicate():
		if link.relation is R_OwnedBy:
			item.remove_relationship(link)
	for existing: Entity in items(destination):
		var other: C_InventoryItem = existing.get_component(C_InventoryItem) as C_InventoryItem
		if not _compatible(state, other) or not other.pending_use_id.is_empty():
			continue
		var added: int = mini(state.quantity, maxi(0, other.definition.maximum_stack - other.quantity))
		other.quantity += added
		state.quantity -= added
		if state.quantity == 0:
			break
	if state.quantity == 0:
		ECS.world.remove_entity(item)
	else:
		item.add_relationship(Relationship.new(R_OwnedBy.new(), destination))
		state.transfer_in_progress = false
	destination_inventory.transfer_in_progress = false
	if previous_inventory != null:
		previous_inventory.transfer_in_progress = false
	return true


static func use_reason(owner: Entity, item: Entity, target: Entity = null) -> String:
	if not _owner_available(owner):
		return "Владелец недоступен или действие ещё выполняется"
	if not EntityAvailability.contains(item, ECS.world):
		return "Стек недоступен"
	if owner_for(item) != owner:
		return "Предмет не принадлежит игроку"
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	if not _valid_item(state) or not state.pending_use_id.is_empty():
		return "Стек недоступен"
	match state.definition.kind:
		DEF_InventoryItem.Kind.FOOD:
			var hunger: C_Hunger = owner.get_component(C_Hunger) as C_Hunger
			if hunger == null or hunger.value <= 0.0:
				return "Голод уже равен нулю"
			if state.definition.food_effect == null or not is_finite(state.definition.food_effect.hunger_relief) or state.definition.food_effect.hunger_relief <= 0.0:
				return "Эффект еды недоступен"
		DEF_InventoryItem.Kind.MED_ITEM:
			var health: C_Health = owner.get_component(C_Health) as C_Health
			if health == null or health.depleted or health.current <= 0.0 or not is_finite(health.current) or not is_finite(health.value):
				return "Лечение недоступно"
			if health.current >= health.value:
				return "Здоровье уже полное"
			if not is_finite(state.definition.healing) or state.definition.healing <= 0.0:
				return "Эффект лечения недоступен"
		DEF_InventoryItem.Kind.BUBBLE_WRAP:
			if not PackageProtectionService.can_apply(target, state.definition.protection_tier):
				return "Наведитесь на целую посылку с меньшей защитой"
		_:
			return "Неизвестный эффект"
	return ""


static func use(owner: Entity, item: Entity, target: Entity = null) -> bool:
	if not use_reason(owner, item, target).is_empty():
		return false
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	var inventory: C_Inventory = owner.get_component(C_Inventory) as C_Inventory
	inventory.use_in_progress = true
	inventory.use_sequence += 1
	state.pending_use_id = StringName("%s%s:%d" % [USE_PREFIX, item.id, inventory.use_sequence])
	if state.definition.kind == DEF_InventoryItem.Kind.MED_ITEM:
		var request: DamageRequest = DamageRequest.new()
		request.source = item
		request.instigator = owner
		request.target = owner
		request.origin_id = state.pending_use_id
		request.operation = DamageRequest.Operation.HEAL
		request.amount = state.definition.healing
		if DamageRequestService.submit(request):
			return true
		_finish_use(owner, item, false)
		return false
	var applied: bool = HungerService.apply_food(owner, state.definition.food_effect) if state.definition.kind == DEF_InventoryItem.Kind.FOOD else PackageProtectionService.apply(target, state.definition.protection_tier)
	_finish_use(owner, item, applied)
	return applied


## Called by the DamageResult observer only after actual Health arithmetic.
static func healing_result(result: DamageResult) -> void:
	if result == null or result.request == null:
		return
	var request: DamageRequest = result.request
	var item: Entity = request.source
	if not _registered(item) or request.operation != DamageRequest.Operation.HEAL:
		return
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	if state == null or state.pending_use_id.is_empty() or request.origin_id != state.pending_use_id:
		return
	var owner: Entity = owner_for(item)
	if owner != request.target or owner != request.instigator:
		return
	_finish_use(owner, item, result.applied_amount > 0.0)


static func clear_owner(owner: Entity) -> void:
	if not is_instance_valid(ECS.world):
		return
	var snapshot: Array[Entity] = ECS.world.query.with_all([C_InventoryItem]).execute().duplicate()
	for item: Entity in snapshot:
		if not _registered(item):
			continue
		for link: Relationship in item.relationships:
			if link.relation is R_OwnedBy and link.target == owner:
				ECS.world.remove_entity(item)
				break


## Direct Entity signal persists when GECS disconnects its own handlers on disable.
static func ownership_removed(item: Entity, link: Relationship) -> void:
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	if state == null or state.transfer_in_progress or not link.relation is R_OwnedBy:
		return
	var owner: Entity = link.target as Entity if is_instance_valid(link.target) else null
	var inventory: C_Inventory = owner.get_component(C_Inventory) as C_Inventory if owner != null else null
	if inventory != null and not state.pending_use_id.is_empty():
		inventory.use_in_progress = false
	if _registered(item) and owner_for(item) == null:
		ECS.world.remove_entity(item)


## World removal/disable retains outgoing links long enough to cancel a pending use.
static func entity_unavailable(entity: Entity) -> void:
	if not is_instance_valid(entity):
		return
	var state: C_InventoryItem = entity.get_component(C_InventoryItem) as C_InventoryItem
	if state != null and not state.pending_use_id.is_empty():
		for link: Relationship in entity.relationships:
			if link.relation is R_OwnedBy and is_instance_valid(link.target):
				var owner: Entity = link.target as Entity
				var inventory: C_Inventory = owner.get_component(C_Inventory) as C_Inventory if owner != null else null
				if inventory != null:
					inventory.use_in_progress = false
		state.pending_use_id = &""
	if entity.has_component(C_Inventory):
		clear_owner(entity)


static func _finish_use(owner: Entity, item: Entity, applied: bool) -> void:
	if not _registered(item):
		return
	var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	state.pending_use_id = &""
	var inventory: C_Inventory = owner.get_component(C_Inventory) as C_Inventory if is_instance_valid(owner) else null
	if inventory != null:
		inventory.use_in_progress = false
	if applied:
		state.quantity -= 1
		if state.quantity <= 0:
			ECS.world.remove_entity(item)


static func _owner_available(owner: Entity) -> bool:
	if not GrabService.holder_available(owner) or owner.has_component(C_Death):
		return false
	var inventory: C_Inventory = owner.get_component(C_Inventory) as C_Inventory
	return inventory != null and inventory.maximum_stacks > 0 and not inventory.use_in_progress and not inventory.transfer_in_progress


static func _valid_item(state: C_InventoryItem) -> bool:
	return state != null and state.definition != null and not state.definition.key.is_empty() and state.definition.maximum_stack > 0 and state.quantity > 0 and state.quantity <= state.definition.maximum_stack


static func _compatible(a: C_InventoryItem, b: C_InventoryItem) -> bool:
	return _valid_item(a) and _valid_item(b) and a.definition == b.definition and not b.transfer_in_progress


static func _registered(entity: Entity) -> bool:
	return is_instance_valid(entity) and is_instance_valid(ECS.world) and not entity.is_queued_for_deletion() and ECS.world.entity_to_archetype.has(entity)
