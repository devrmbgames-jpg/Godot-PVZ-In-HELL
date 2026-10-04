extends System
## Удаляет истёкшие/отключённые опасности после последнего такта производителей урона.
class_name S_HazardLifetime


## Выбирает все опасности с TTL, включая отключённые.
func query() -> QueryBuilder:
	return q.with_all([C_Hazard, C_HazardLifetime]).iterate([C_HazardLifetime])


## Уменьшает TTL в секундах вне ожидания эффекта и планирует удаление истёкших/отключённых.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var lifetimes: Array = components[0]
	for index: int in entities.size():
		var lifetime: C_HazardLifetime = lifetimes[index]
		if not lifetime.awaiting_resolution:
			lifetime.remaining_seconds = maxf(0.0, lifetime.remaining_seconds - delta)
		if not entities[index].enabled or lifetime.remaining_seconds <= 0.0:
			cmd.add_custom(HazardLifecycle.retire.bind(entities[index], _world))
