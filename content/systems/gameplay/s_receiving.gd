extends System
## Schedules pending Receiving work; spawning/construction live in services.
class_name S_Receiving


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase] }


func query() -> QueryBuilder:
	return q.with_all([C_Receiving]).iterate([C_Receiving])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	if cycle == null or cycle.phase != C_DayCycle.Phase.MORNING:
		return
	var states: Array = components[0]
	for index: int in entities.size():
		var zone: E_ReceivingZone = entities[index] as E_ReceivingZone
		var receiving: C_Receiving = states[index]
		receiving.retry_remaining = maxf(0.0, receiving.retry_remaining - delta)
		if receiving.retry_remaining > 0.0 or zone == null:
			continue
		cmd.add_custom(ReceivingDeliveryService.deliver_one.bind(
			zone,
			receiving,
			cycle.day_index,
		))
