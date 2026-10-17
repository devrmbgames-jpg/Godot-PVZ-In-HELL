extends System
## Плановая выдача принятых партий и наблюдение получения; смерть NPC не отменяет обещание.
class_name S_Crafting


#region Ограниченное исполнение обещаний
func _init() -> void:
	group = "GamePlay"


func deps() -> Dictionary[int, Array]:
	return { Runs.After: [S_DayPhase] }


func query() -> QueryBuilder:
	return q.with_all([C_Crafting]).iterate([C_Crafting])


func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if (
		cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT
		or delta < 0.0 or not is_finite(delta)
	):
		return
	var commerce: C_Commerce = CommerceService.current()
	if commerce == null or commerce.transaction_in_progress:
		return
	for index: int in entities.size():
		var state: C_Crafting = components[0][index] as C_Crafting
		if state.retry_queued:
			continue
		state.retry_remaining = maxf(0.0, state.retry_remaining - delta)
		if state.retry_remaining > 0.0:
			continue
		var container: E_CraftingContainer = entities[index] as E_CraftingContainer
		var batch: CraftingBatch = CraftingQueries.active(container)
		if batch == null or not batch.consumed or batch.ready_day > cycle.day_index:
			continue
		state.retry_queued = true
		state.retry_revision += 1
		cmd.add_custom(
			_fulfil.bind(weakref(container), state, batch, cycle.day_index, state.retry_revision),
		)


func _fulfil(
	reference: WeakRef,
	state: C_Crafting,
	batch: CraftingBatch,
	day: int,
	revision: int,
) -> void:
	if state.retry_revision != revision:
		return
	state.retry_queued = false
	var container: E_CraftingContainer = reference.get_ref() as E_CraftingContainer
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if (
		ECS.world != _world or not EntityAvailability.contains(container, _world)
		or container.get_component(C_Crafting) != state or cycle == null or cycle.day_index != day
		or cycle.phase == C_DayCycle.Phase.NIGHT or CraftingQueries.active(container) != batch
		or CommerceService.current().transaction_in_progress
	):
		return
	state.retry_remaining = state.profile.placement.retry_seconds
	var changed: bool = false
	var attempts: int = 0
	var complete: bool = true
	for output: CraftingOutput in batch.outputs:
		if not output.emitted and attempts < state.profile.placement.retry_budget:
			attempts += 1
			if CraftingOutputService.place(container, state, output):
				changed = true
			if (
				ECS.world != _world or not EntityAvailability.contains(container, _world)
				or container.get_component(C_Crafting) != state
			):
				return
		if output.emitted and not output.taken:
			var item: Entity = _world.entity_id_registry.get(output.entity_id) as Entity
			if not EntityAvailability.contains(item, _world) or not container.contains(item):
				output.taken = true
				changed = true
			elif (
				not item.get_relationships(Relationship.new(R_HeldBy.new())).is_empty()
				or not item.get_relationships(Relationship.new(R_OwnedBy.new())).is_empty()
			):
				output.taken = true
				changed = true
		if not output.emitted or not output.taken:
			complete = false
	if complete:
		batch.completed = true
		changed = true
	if changed and EntityAvailability.contains(container, _world):
		_world.emit_event(CraftingService.EVENT, container)
#endregion
