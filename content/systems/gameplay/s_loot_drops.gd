extends System
## Редко повторяет ограниченную часть очереди лута через CommandBuffer, независимо от AI.
class_name S_LootDrops

#region Сессионная очередь
## Повторы участвуют в обычной группе игровой логики уровня.
func _init() -> void:
	group = "GamePlay"

## Очередь исполняется после фазы дня и до ночного снимка.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_DayPhase], Runs.Before: [S_NightSave]}

## Выбирает только сессию с ожидающим лутом и циклом дня.
func query() -> QueryBuilder:
	return q.with_all([C_LootDrops, C_DayCycle]).iterate([C_LootDrops, C_DayCycle])

## Во время сна не создаёт предметы; в остальных фазах повтор ограничен настройкой очереди.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var queues: Array = components[0]
	var cycles: Array = components[1]
	for index: int in entities.size():
		var queue: C_LootDrops = queues[index] as C_LootDrops
		var cycle: C_DayCycle = cycles[index] as C_DayCycle
		if queue.pending.is_empty() or cycle.phase == C_DayCycle.Phase.NIGHT:
			continue
		queue.retry_remaining = maxf(0.0, queue.retry_remaining - delta)
		if queue.retry_remaining <= 0.0:
			cmd.add_custom(LootDropService.retry.bind(entities[index], queue))
#endregion
