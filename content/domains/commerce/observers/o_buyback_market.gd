extends Observer
## Дискретная граница фактического прибытия; late capability восстанавливает прайс из arrival truth.
class_name O_BuybackMarket


#region Реактивные границы
func sub_observers() -> Array[Array]:
	return [
		[q.on_event(ReceivingSupplyCompleted.EVENT), _on_supply],
		[q.on_event(BuybackSale.EVENT), _on_container],
		[q.with_all([C_Buyback]).on_match(), _on_container, true],
	]


func _on_supply(_event: Variant, zone: Entity, payload: Variant = null) -> void:
	var fact: ReceivingSupplyCompleted = payload as ReceivingSupplyCompleted
	assert(fact != null)
	cmd.add_custom(_accept_supply.bind(weakref(zone), fact))


func _accept_supply(zone_reference: WeakRef, fact: ReceivingSupplyCompleted) -> void:
	var zone: Entity = zone_reference.get_ref() as Entity
	if (
		ECS.world != _world or not EntityAvailability.contains(zone, _world)
		or zone.get_component(C_Receiving) != fact.receiving
		or fact.receiving.batch_id != fact.batch_id
		or fact.receiving.last_started_day != fact.day_index
	):
		return
	for candidate: Entity in _world.query.with_all([C_Buyback]).execute():
		var state: C_Buyback = candidate.get_component(C_Buyback) as C_Buyback
		BuybackMarketService.accept_supply(state, fact)
		_show_market(candidate as E_BuybackContainer, state)


func _on_container(_event: Variant, container: Entity, _payload: Variant = null) -> void:
	var state: C_Buyback = container.get_component(C_Buyback) as C_Buyback
	cmd.add_custom(_reconcile_container.bind(weakref(container), state))


func _reconcile_container(container_reference: WeakRef, state: C_Buyback) -> void:
	var container: E_BuybackContainer = container_reference.get_ref() as E_BuybackContainer
	if (
		ECS.world != _world or not EntityAvailability.contains(container, _world)
		or container.get_component(C_Buyback) != state
	):
		return
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null:
		return
	if state.profile.pricing == DEF_BuybackProfile.Pricing.FIXED:
		BuybackMarketService.prepare_fixed(state, cycle.day_index)
	else:
		for zone: Entity in _world.query.with_all([C_Receiving]).execute():
			var receiving: C_Receiving = zone.get_component(C_Receiving) as C_Receiving
			if receiving.last_started_day != cycle.day_index or not receiving.pending.is_empty():
				continue
			BuybackMarketService.accept_supply(
				state,
				ReceivingSupplyCompleted.new(receiving, PackageQueries.ledger()),
			)
	_show_market(container, state)


func _show_market(container: E_BuybackContainer, state: C_Buyback) -> void:
	var lines: PackedStringArray = [state.profile.display_name]
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if state.price_day == 0 or cycle == null or state.price_day != cycle.day_index:
		lines.append("Жду поставку")
	elif state.premium_item_keys.is_empty():
		lines.append("Нет дневных позиций повышенного спроса")
	else:
		for key: String in state.premium_item_keys:
			var remaining: int = 0 if key in state.premium_spent_keys else 1
			for price: BuybackItemPrice in state.prices:
				if String(price.definition.key) == key:
					lines.append(
						"%s · %d · осталось %d"
						% [price.definition.display_name, price.premium_price, remaining]
					)
	container.show_message("\n".join(lines))
#endregion
