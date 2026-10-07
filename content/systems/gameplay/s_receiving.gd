extends System
## Планирует ожидающую поставку утром; создание и размещение коробок выполняют сервисы.
class_name S_Receiving


#region Планирование приёмки
## Выполняет приёмку после обновления фазы дня S_DayPhase.
func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase] }


## Выбирает зоны с C_Receiving и передаёт их состояние в пакет системы.
func query() -> QueryBuilder:
	return q.with_all([C_Receiving]).iterate([C_Receiving])


## Утром уменьшает паузу повторов в секундах и откладывает доставку через CommandBuffer.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null:
		return

	var states: Array = components[0]
	for index: int in entities.size():
		var zone: E_ReceivingZone = entities[index] as E_ReceivingZone
		var receiving: C_Receiving = states[index]
		if cycle.phase != C_DayCycle.Phase.MORNING:
			if zone != null and zone.get_truck() != null and not zone.get_truck().is_departing():
				cmd.add_custom(ReceivingShiftService.request_departure.bind(zone))
			continue
		receiving.retry_remaining = maxf(0.0, receiving.retry_remaining - delta)
		if receiving.retry_remaining > 0.0 or zone == null:
			continue

		cmd.add_custom(ReceivingDeliveryService.deliver_one.bind(
			zone,
			receiving,
			cycle.day_index,
		))

#endregion
