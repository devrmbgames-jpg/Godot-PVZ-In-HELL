extends RefCounted
## Читает одну авторскую точку покупателя и физические ограничения товара без продажи или оплаты.
class_name BuybackQueries


#region Точка и доступность
## Разрешает точку по постоянной личности, не хранит второй roster или mutable Entity map.
static func container_for(trader: Entity) -> E_BuybackContainer:
	var identity: C_NpcIdentity = trader.get_component(C_NpcIdentity) as C_NpcIdentity
	if identity == null:
		return null
	var found: E_BuybackContainer = null
	for candidate: Entity in ECS.world.query.with_all([C_Buyback]).execute():
		var state: C_Buyback = candidate.get_component(C_Buyback) as C_Buyback
		if state.profile == null or state.profile.npc_id != identity.npc_id:
			continue
		# У каждой личности одна авторская точка; дубликат не создаёт второй premium лимит.
		if found != null:
			return null
		found = candidate as E_BuybackContainer
	return found


## Не раскрывает причину смерти; живой покупатель, фаза и реальный прайс проверяются заново.
static func unavailable_reason(state: C_Buyback, trader: Entity, cycle: C_DayCycle) -> String:
	if not GrabQueries.holder_available(trader) or trader.has_component(C_Death):
		return "Покупатель недоступен"
	if cycle == null or state.profile == null:
		return "Скупка не настроена"
	if (
		cycle.phase == C_DayCycle.Phase.NIGHT
		or (state.profile.open_phases & (1 << cycle.phase)) == 0
	):
		return "Сейчас скупка закрыта"
	if state.transaction_in_progress:
		return "Расчёт уже выполняется"
	# Весь manifest грузовика фиксируется до callbacks удаления; новая сделка ждёт эту границу.
	for zone: Entity in ECS.world.query.with_all([C_Receiving]).execute():
		if (zone.get_component(C_Receiving) as C_Receiving).cargo_commit_in_progress:
			return "Дождитесь завершения отгрузки"
	if state.profile.pricing == DEF_BuybackProfile.Pricing.DEMON_DAILY:
		if state.price_day != cycle.day_index:
			return "Жду поставку"
		if state.premium_item_keys.is_empty():
			return "В поставке нет подходящего товара для спроса"
	return ""
#endregion


#region Только свободное реальное имущество
## reservation_owner задан только повторной проверкой уже захваченной подтверждаемой партии.
static func item_reason(
	container: E_BuybackContainer,
	item: Entity,
	reservation_owner: Entity = null,
) -> String:
	if not EntityAvailability.contains(item, ECS.world):
		return "Предмет недоступен"
	var body: RigidBody3D = item as Node as RigidBody3D
	if body == null or body.freeze or body.is_in_group(GrabQueries.NO_CARRY_GROUP):
		return "Неподвижный предмет"
	if item.has_component(C_Package):
		return "Посылки не продаются как барахло"
	if item.has_component(C_Living) or item.has_component(C_NpcIdentity):
		return "Живые существа и тела не принимаются"
	if not container.contains(item):
		return "Положите предмет целиком внутрь контейнера"
	if item.has_component(C_PlayerAnchored):
		return "Предмет закреплён"
	for link: Relationship in item.relationships:
		if link.relation is R_BuybackReserved:
			if link.target != reservation_owner:
				return "Предмет уже зарезервирован"
		elif (
			link.relation is R_OwnedBy or link.relation is R_HeldBy or link.relation is R_StoredIn
			or link.relation is R_CartCargo or link.relation is R_InspectionCargo
		):
			return "Сначала освободите предмет"
	var stack: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
	if stack == null or stack.definition == null:
		return "Нет авторской оценки"
	if (
		stack.quantity < 1 or stack.quantity > stack.definition.maximum_stack
		or stack.transfer_in_progress or not stack.pending_use_id.is_empty()
	):
		return "Предмет используется"
	if String(stack.definition.key) in (container.get_component(C_Buyback) as C_Buyback) \
			.profile \
			.rejected_item_keys:
		return "Покупатель не принимает этот предмет"
	# Оболочка не продаёт скрытое содержимое её слотов или инвентаря.
	for candidate: Entity in ECS.world.entities:
		for link: Relationship in candidate.relationships:
			if (
				link.relation is R_StoredIn or link.relation is R_OwnedBy
				or link.relation is R_CartCargo
			):
				if link.target == item or item.is_ancestor_of(link.target):
					return "Сначала опорожните контейнер"
	return ""
#endregion
