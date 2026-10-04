extends System
## Планирует выдачу оплаченных заказов в физической зоне через сервис доставки.
class_name S_OrderDelivery


## Выполняется после системы фаз, чтобы выдавать заказы уже наступившего утра.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase] }


## Выбирает физические зоны выдачи оплаченных заказов.
func query() -> QueryBuilder:
	return q.with_all([C_OrderReceiving]).iterate([C_OrderReceiving])


## Только утром ставит исполнение готового заказа каждой зоны в CommandBuffer.
func process(entities: Array[Entity], components: Array, _delta: float) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	var commerce: C_Commerce = CommerceService.current()
	if cycle == null or commerce == null or cycle.phase != C_DayCycle.Phase.MORNING:
		return

	var states: Array = components[0]
	for index: int in entities.size():
		cmd.add_custom(OrderDeliveryService.fulfill_one.bind(entities[index], states[index] as C_OrderReceiving, commerce, cycle.day_index))
