extends RefCounted
## Явный приём всей партии; обещание фиксируется до однократного выбытия материалов.
class_name CraftingService

enum Status {
	COMMITTED,
	DUPLICATE,
	CHANGED,
	UNAVAILABLE,
	CONFLICT,
}

## Дискретный факт после полного принятия; presentation и scheduler не принимают партию сами.
const EVENT: StringName = &"crafting_batch_changed"


#region Предложение без расхода
## UI видит весь передаваемый состав; готовый рецепт не выбирается из гарантированного меню.
static func quote(actor: Entity, container: E_CraftingContainer) -> CraftingQuote:
	var result: CraftingQuote = CraftingQuote.new()
	result.reason = CraftingQueries.available_reason(container, actor)
	if not result.reason.is_empty():
		return result
	var state: C_Crafting = container.get_component(C_Crafting) as C_Crafting
	result = _evaluate(container, state, DayPhaseQueries.current().day_index)
	if result.reason.is_empty() and not result.inputs.is_empty():
		result.operation_id = CommerceService.next_id("crafting/" + container.id)
	return result


static func _evaluate(
	container: E_CraftingContainer,
	state: C_Crafting,
	day: int,
	reserved: bool = false,
) -> CraftingQuote:
	var result: CraftingQuote = CraftingQuote.new()
	result.container_reference = weakref(container)
	result.state = state
	result.day_index = day
	for body: RigidBody3D in container.bodies():
		var item: Entity = body as Node as Entity
		result.reason = CraftingQueries.item_reason(container, item, reserved)
		if not result.reason.is_empty():
			return result
		result.inputs.append(CraftingQueries.input_for(item))
	result.inputs.sort_custom(
		func(first: CraftingInput, second: CraftingInput) -> bool:
			return first.entity_id < second.entity_id,
	)
	if result.inputs.is_empty():
		result.reason = "Положите материалы в ящик"
		return result
	result.signature = CraftingRecipeRules.signature(
		container.id,
		day,
		state.profile,
		CraftingQueries.grace_used(state.profile),
		result.inputs,
	)
	return result
#endregion


#region Синхронное принятие
## Все стеки, включая подарок, выбывают ровно один раз; деньги никогда не начисляются.
static func confirm(actor: Entity, offer: CraftingQuote) -> Status:
	if offer == null or offer.container_reference == null or offer.operation_id.is_empty():
		return Status.UNAVAILABLE
	var world: World = ECS.world
	var container: E_CraftingContainer = offer.container_reference.get_ref() as E_CraftingContainer
	if (
		not EntityAvailability.contains(container, world)
		or container.get_component(C_Crafting) != offer.state
	):
		return Status.UNAVAILABLE
	var commerce: C_Commerce = CommerceService.current()
	if commerce == null or commerce.transaction_in_progress:
		return Status.UNAVAILABLE
	for previous: CraftingBatch in commerce.crafting_batches:
		if previous.operation_id != offer.operation_id:
			continue
		if previous.container_id != container.id or previous.signature != offer.signature:
			return Status.CONFLICT
		if not previous.consumed:
			return Status.UNAVAILABLE
		for item: CraftingInput in previous.inputs:
			if not item.removed:
				return Status.UNAVAILABLE
		return Status.DUPLICATE
	if not CraftingQueries.available_reason(container, actor).is_empty():
		return Status.UNAVAILABLE
	var state: C_Crafting = offer.state
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var fresh: CraftingQuote = _evaluate(container, state, cycle.day_index)
	if not fresh.reason.is_empty() or fresh.signature != offer.signature:
		return Status.CHANGED
	fresh.operation_id = offer.operation_id
	commerce.transaction_in_progress = true
	var reserved: Array[WeakRef] = []
	var status: Status = _commit(world, actor, container, state, commerce, fresh, reserved)
	for reference: WeakRef in reserved:
		if not is_instance_valid(world):
			break
		var item: Entity = reference.get_ref() as Entity
		if not is_instance_valid(item) or not world.entity_to_archetype.has(item):
			continue
		for link: Relationship in item.relationships.duplicate():
			if link.relation is R_CraftingReserved and link.target == container:
				item.remove_relationship(link)
	commerce.transaction_in_progress = false
	if (
		status == Status.COMMITTED and ECS.world == world
		and EntityAvailability.contains(container, world)
		and container.get_component(C_Crafting) == state
	):
		world.emit_event(EVENT, container)
	return status


static func _commit(
	world: World,
	actor: Entity,
	container: E_CraftingContainer,
	state: C_Crafting,
	commerce: C_Commerce,
	offer: CraftingQuote,
	reserved: Array[WeakRef],
) -> Status:
	for line: CraftingInput in offer.inputs:
		var item: Entity = world.entity_id_registry.get(line.entity_id) as Entity
		if not EntityAvailability.contains(item, world):
			return Status.CHANGED
		reserved.append(weakref(item))
		item.add_relationship(Relationship.new(R_CraftingReserved.new(), container))
		if (
			not is_instance_valid(world) or ECS.world != world
			or not EntityAvailability.contains(container, world)
			or container.get_component(C_Crafting) != state or CommerceService.current() != commerce
		):
			return Status.UNAVAILABLE
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if (
		cycle == null or cycle.phase == C_DayCycle.Phase.NIGHT
		or not GrabQueries.holder_available(actor) or actor.has_component(C_Death)
	):
		return Status.UNAVAILABLE
	var fresh: CraftingQuote = _evaluate(container, state, cycle.day_index, true)
	if not fresh.reason.is_empty() or fresh.signature != offer.signature:
		return Status.CHANGED
	var plan: CraftingPlan = CraftingRecipeRules.plan(fresh.inputs, state.profile.recipes)
	if not plan.reason.is_empty():
		return Status.UNAVAILABLE
	var batch: CraftingBatch = CraftingBatch.new()
	batch.operation_id = offer.operation_id
	batch.container_id = container.id
	batch.profile = state.profile
	batch.signature = offer.signature
	batch.accepted_day = cycle.day_index
	batch.ready_day = cycle.day_index + 1
	batch.inputs = fresh.inputs
	batch.recipes = plan.recipes
	batch.gifts = plan.gifts
	batch.first_failure = plan.recipes.is_empty() and not CraftingQueries.grace_used(state.profile)
	for recipe: DEF_CraftingRecipe in plan.recipes:
		_append_outputs(batch, recipe.output, recipe.output_quantity)
	if plan.recipes.is_empty() and not batch.first_failure:
		_append_outputs(batch, state.profile.trash, state.profile.trash_quantity)
	# Обещание и первая льгота становятся видимыми до структурных callbacks выбытия.
	commerce.crafting_batches.append(batch)
	for index: int in batch.inputs.size():
		batch.inputs[index].removed = true
		if not is_instance_valid(world):
			continue
		var item: Entity = reserved[index].get_ref() as Entity
		if is_instance_valid(item) and world.entity_to_archetype.has(item):
			world.remove_entity(item)
	for gift: CraftingInput in batch.gifts:
		gift.removed = true
	batch.consumed = true
	return Status.COMMITTED


static func _append_outputs(
	batch: CraftingBatch,
	definition: DEF_InventoryItem,
	count: int,
) -> void:
	for index: int in count:
		var output: CraftingOutput = CraftingOutput.new()
		output.entity_id = "%s/output/%d" % [batch.operation_id, batch.outputs.size()]
		output.definition = definition
		batch.outputs.append(output)
#endregion
