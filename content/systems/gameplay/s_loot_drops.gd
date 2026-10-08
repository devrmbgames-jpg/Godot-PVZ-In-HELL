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
	if not is_finite(delta) or delta < 0.0:
		return

	var queues: Array = components[0]
	var cycles: Array = components[1]
	for index: int in entities.size():
		var queue: C_LootDrops = queues[index] as C_LootDrops
		var cycle: C_DayCycle = cycles[index] as C_DayCycle
		if queue.pending.is_empty() or queue.retry_queued or cycle.phase == C_DayCycle.Phase.NIGHT:
			continue
		queue.retry_remaining = maxf(0.0, queue.retry_remaining - delta)
		if queue.retry_remaining > 0.0:
			continue

		var placement: DEF_ItemPlacement = queue.placement
		assert(placement != null, "Loot retry requires its authored placement policy")
		var attempts: int = mini(queue.pending.size(), placement.retry_budget)
		var records: Array[PendingLootDrop] = queue.pending.slice(0, attempts)
		queue.retry_queued = true
		queue.retry_revision += 1
		cmd.add_custom(_retry.bind(weakref(entities[index]), queue, cycle, cycle.day_index, cycle.phase, placement, records, queue.retry_revision))
#endregion

#region Bounded retry commit
func _retry(
	session_reference: WeakRef, queue: C_LootDrops, cycle: C_DayCycle, day: int,
	phase: C_DayCycle.Phase, placement: DEF_ItemPlacement, records: Array[PendingLootDrop], revision: int,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if queue.retry_revision != revision:
		return
	_retry_records(session, queue, cycle, day, phase, placement, records, revision)
	if queue.retry_revision == revision:
		queue.retry_queued = false


func _retry_records(
	session: Entity, queue: C_LootDrops, cycle: C_DayCycle, day: int,
	phase: C_DayCycle.Phase, placement: DEF_ItemPlacement, records: Array[PendingLootDrop], revision: int,
) -> void:
	if not _matches(session, queue, cycle, day, phase, placement, revision):
		return

	queue.retry_remaining = placement.retry_seconds
	for record: PendingLootDrop in records:
		# Registration can invoke synchronous lifecycle reactions; every next record revalidates ownership.
		if not _matches(session, queue, cycle, day, phase, placement, revision):
			return
		if record not in queue.pending or not queue.committed_batches.has(record.batch_id):
			continue

		var placed: Entity = LootDropService.place_pending(queue, record)
		if not _matches(session, queue, cycle, day, phase, placement, revision):
			return
		if record in queue.pending:
			queue.pending.erase(record)
			if placed == null:
				queue.pending.append(record)


func _matches(
	session: Entity, queue: C_LootDrops, cycle: C_DayCycle, day: int,
	phase: C_DayCycle.Phase, placement: DEF_ItemPlacement, revision: int,
) -> bool:
	return (
		EntityAvailability.contains(session, _world)
		and session.get_component(C_LootDrops) == queue
		and session.get_component(C_DayCycle) == cycle
		and cycle.day_index == day and cycle.phase == phase and phase != C_DayCycle.Phase.NIGHT
		and queue.placement == placement and queue.retry_revision == revision
	)
#endregion
