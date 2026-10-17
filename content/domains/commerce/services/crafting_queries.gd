extends RefCounted
## Чтение одной мастерской/истории и фактической пригодности материалов без расхода.
class_name CraftingQueries


#region История единственного владельца
## Все долговременные факты живут в C_Commerce, а не в жизни NPC или UI.
static func batches() -> Array[CraftingBatch]:
	var commerce: C_Commerce = CommerceService.current()
	return commerce.crafting_batches if commerce != null else []


## У каждой личности одна каноническая точка; новая коробка не сбрасывает прошлую льготу.
static func available_reason(container: E_CraftingContainer, actor: Entity) -> String:
	if not EntityAvailability.contains(container, ECS.world):
		return "Мастерская недоступна"
	if not GrabQueries.holder_available(actor) or actor.has_component(C_Death):
		return "Игрок недоступен"
	var state: C_Crafting = container.get_component(C_Crafting) as C_Crafting
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var commerce: C_Commerce = CommerceService.current()
	if state == null or state.profile == null or cycle == null or commerce == null:
		return "Мастерская не настроена"
	if cycle.phase == C_DayCycle.Phase.NIGHT or commerce.transaction_in_progress:
		return "Сейчас передача недоступна"
	var profile: DEF_CraftingProfile = state.profile
	if (
		profile.resource_path.is_empty() or profile.hint_recipe not in profile.recipes
		or profile.trash == null or profile.trash_quantity < 1
		or not CraftingRecipeRules.catalog_error(profile.recipes).is_empty()
	):
		return "Каталог мастерской не настроен"
	for point: Entity in ECS.world.query.with_all([C_Crafting]).execute():
		var other: C_Crafting = point.get_component(C_Crafting) as C_Crafting
		if point != container and other.profile != null and other.profile.npc_id == profile.npc_id:
			return "У мастерской несколько точек"
	for batch: CraftingBatch in commerce.crafting_batches:
		if batch.profile.npc_id != profile.npc_id:
			continue
		if batch.container_id != container.id or batch.profile != profile:
			return "Принятые партии закреплены за другой точкой"
		if not batch.completed:
			return "Сначала заберите предыдущую партию"
	for zone: Entity in ECS.world.query.with_all([C_Receiving]).execute():
		if (zone.get_component(C_Receiving) as C_Receiving).cargo_commit_in_progress:
			return "Дождитесь завершения отгрузки"
	return ""


## Первая неудача определяется кампанийной историей, даже если сам ящик временно отсутствовал.
static func grace_used(profile: DEF_CraftingProfile) -> bool:
	for batch: CraftingBatch in batches():
		if batch.profile.npc_id == profile.npc_id and batch.first_failure:
			return true
	return false


## Незавершённое обещание точной native точки; смерть изготовителя его не отменяет.
static func active(container: E_CraftingContainer) -> CraftingBatch:
	for batch: CraftingBatch in batches():
		if batch.container_id == container.id and not batch.completed:
			return batch
	return null
#endregion


#region Реальное имущество и состояние
## reservations доступны только повторной проверке той же подтверждаемой партии.
static func item_reason(
	container: E_CraftingContainer,
	item: Entity,
	reserved: bool = false,
) -> String:
	if not EntityAvailability.contains(item, ECS.world):
		return "В ящике есть неподдерживаемое тело"
	var body: RigidBody3D = item as Node as RigidBody3D
	if body == null or body.freeze or body.is_in_group(GrabQueries.NO_CARRY_GROUP):
		return "Сначала уберите закреплённый предмет"
	if (
		item.has_component(C_Package) or item.has_component(C_Living)
		or item.has_component(C_NpcIdentity) or item.has_component(C_PlayerAnchored)
	):
		return "Посылки, тела и закреплённые предметы не передаются"
	if not container.contains(item):
		return "Положите все предметы целиком внутрь ящика"
	for link: Relationship in item.relationships:
		if link.relation is R_CraftingReserved:
			if not reserved or link.target != container:
				return "Материал зарезервирован"
		elif (
			link.relation is R_BuybackReserved or link.relation is R_OwnedBy
			or link.relation is R_HeldBy or link.relation is R_StoredIn
			or link.relation is R_CartCargo or link.relation is R_InspectionCargo
		):
			return "Сначала освободите материал"
	var stack: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	if (
		stack == null or stack.definition == null or stack.definition.resource_path.is_empty()
		or stack.quantity < 1 or stack.quantity > stack.definition.maximum_stack
		or stack.transfer_in_progress or not stack.pending_use_id.is_empty()
	):
		return "Материал нельзя передать сейчас"
	for candidate: Entity in ECS.world.entities:
		for link: Relationship in candidate.relationships:
			if (
				link.relation is R_StoredIn or link.relation is R_OwnedBy
				or link.relation is R_CartCargo or link.relation is R_InspectionCargo
			):
				if link.target == item or item.is_ancestor_of(link.target):
					return "Сначала опорожните предмет"
	return ""


## Захватывает факты однократно до расхода; чужое извлечённое содержимое не запрещается.
static func input_for(item: Entity) -> CraftingInput:
	var stack: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	var result: CraftingInput = CraftingInput.new()
	result.entity_id = item.id
	result.definition = stack.definition
	result.quantity = stack.quantity
	result.source_package_id = stack.source_package_id
	result.source_history_id = stack.source_history_id
	var health: C_Health = item.get_component(C_Health) as C_Health
	result.intact = (health == null or health.value > 0.0) and not item.has_component(C_Death)
	var emitter: C_HazardEmitter = item.get_component(C_HazardEmitter) as C_HazardEmitter
	result.full_blood = (
		stack.definition.key == &"blood_flask" and result.intact and emitter != null
		and emitter.one_shot and not emitter.fired and emitter.sequence == 0
	)
	return result
#endregion
