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
	if not is_finite(delta) or delta < 0.0:
		return

	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null:
		return

	var states: Array = components[0]
	for index: int in entities.size():
		var zone: E_ReceivingZone = entities[index] as E_ReceivingZone
		var receiving: C_Receiving = states[index]
		if cycle.phase != C_DayCycle.Phase.MORNING:
			if zone != null and zone.get_truck() != null and not zone.get_truck().is_departing():
				cmd.add_custom(_depart.bind(weakref(zone), receiving, cycle, cycle.day_index, cycle.phase, receiving.context_revision))
			continue
		receiving.retry_remaining = maxf(0.0, receiving.retry_remaining - delta)
		if receiving.retry_remaining > 0.0 or zone == null:
			continue

		cmd.add_custom(_deliver.bind(weakref(zone), receiving, cycle, cycle.day_index, receiving.last_started_day, receiving.batch_id, receiving.context_revision))

#endregion

#region Captured receiving commits
func _deliver(
	zone_reference: WeakRef, receiving: C_Receiving, cycle: C_DayCycle, day: int, started_day: int,
	batch_id: String, revision: int,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var zone: E_ReceivingZone = zone_reference.get_ref() as E_ReceivingZone

	if not _matches(zone, receiving, cycle, day, C_DayCycle.Phase.MORNING):
		return
	if receiving.last_started_day != started_day or receiving.batch_id != batch_id or receiving.context_revision != revision:
		return
	ReceivingDeliveryService.deliver_one(zone, receiving, day)


func _depart(zone_reference: WeakRef, receiving: C_Receiving, cycle: C_DayCycle, day: int, phase: C_DayCycle.Phase, revision: int) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var zone: E_ReceivingZone = zone_reference.get_ref() as E_ReceivingZone

	if receiving.context_revision != revision:
		return
	if _matches(zone, receiving, cycle, day, phase):
		ReceivingShiftService.request_departure(zone)


func _matches(zone: E_ReceivingZone, receiving: C_Receiving, cycle: C_DayCycle, day: int, phase: C_DayCycle.Phase) -> bool:
	return (
		EntityAvailability.contains(zone, _world) and zone.get_component(C_Receiving) == receiving
		and DayPhaseQueries.current() == cycle and cycle.day_index == day and cycle.phase == phase
	)
#endregion
