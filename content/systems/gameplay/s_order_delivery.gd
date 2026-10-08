extends System
## Планирует выдачу оплаченных заказов в физической зоне через сервис доставки.
class_name S_OrderDelivery


#region Утренняя выдача
## Выполняется после системы фаз, чтобы выдавать заказы уже наступившего утра.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase] }


## Выбирает физические зоны выдачи оплаченных заказов.
func query() -> QueryBuilder:
	return q.with_all([C_OrderReceiving]).iterate([C_OrderReceiving])


## Только утром ставит исполнение готового заказа каждой зоны в CommandBuffer.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return

	var cycle: C_DayCycle = DayPhaseService.current()
	var commerce: C_Commerce = CommerceService.current()
	if cycle == null or commerce == null or cycle.phase != C_DayCycle.Phase.MORNING:
		return

	var states: Array = components[0]
	for index: int in entities.size():
		var state: C_OrderReceiving = states[index] as C_OrderReceiving
		if state.attempt_day != cycle.day_index:
			state.attempt_day = cycle.day_index
			state.retry_remaining = 0.0
			state.exhausted = false
		if state.exhausted or state.delivery_queued:
			continue

		state.retry_remaining = maxf(0.0, state.retry_remaining - delta)
		if state.retry_remaining > 0.0:
			continue
		state.retry_remaining = state.retry_seconds
		state.delivery_queued = true
		state.delivery_revision += 1
		cmd.add_custom(_fulfill.bind(weakref(entities[index]), state, commerce, cycle, cycle.day_index, state.delivery_revision))

#endregion

#region Captured delivery commit
func _fulfill(zone_reference: WeakRef, state: C_OrderReceiving, commerce: C_Commerce, cycle: C_DayCycle, day: int, revision: int) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var zone: Entity = zone_reference.get_ref() as Entity

	if state.delivery_revision != revision:
		return
	_fulfill_current(zone, state, commerce, cycle, day)
	if state.delivery_revision == revision:
		state.delivery_queued = false


func _fulfill_current(zone: Entity, state: C_OrderReceiving, commerce: C_Commerce, cycle: C_DayCycle, day: int) -> void:
	if not EntityAvailability.contains(zone, _world) or zone.get_component(C_OrderReceiving) != state:
		return
	if CommerceService.current() != commerce or DayPhaseService.current() != cycle:
		return
	if cycle.phase != C_DayCycle.Phase.MORNING or cycle.day_index != day:
		return
	OrderDeliveryService.fulfill_one(zone, state, commerce, day)
#endregion
