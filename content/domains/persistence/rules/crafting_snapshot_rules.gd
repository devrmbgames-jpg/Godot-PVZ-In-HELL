extends RefCounted
## Проверяет принятые материалы, кампанийную льготу и однократные физические результаты.
class_name CraftingSnapshotRules


#region Decoded история без live World
static func valid(
	components: Dictionary[String, Dictionary],
	records: Dictionary[String, Dictionary],
) -> bool:
	var commerce: C_Commerce = null
	var cycle: C_DayCycle = null
	var arrivals: Dictionary[String, PackageRegistrationRecord] = { }
	var points: Dictionary[String, C_Crafting] = { }
	var live: Dictionary[String, String] = { }
	for key: String in records:
		live[String(records[key].entity_id)] = key
	var identities: Array[StringName] = []
	for key: String in components:
		var types: Dictionary = components[key]
		if types.has(C_Commerce):
			if commerce != null:
				return false
			commerce = types[C_Commerce] as C_Commerce
		if types.has(C_DayCycle):
			cycle = types[C_DayCycle] as C_DayCycle
		if types.has(C_PackageLedger):
			for arrival: PackageRegistrationRecord in (
				types[C_PackageLedger] as C_PackageLedger
			).records:
				arrivals[arrival.package_id] = arrival
		if types.has(C_Crafting):
			var state: C_Crafting = types[C_Crafting] as C_Crafting
			if not _profile_valid(state.profile) or state.profile.npc_id in identities:
				return false
			identities.append(state.profile.npc_id)
			points[String(records[key].entity_id)] = state
	if commerce == null:
		return points.is_empty()
	if commerce.crafting_batches.is_empty():
		return true
	if cycle == null:
		return false
	var consumed: Dictionary[String, bool] = { }
	for sale: BuybackSale in commerce.buyback_sales:
		for item: BuybackSaleItem in sale.items:
			consumed[item.entity_id] = true
	var operations: Array[StringName] = []
	var output_ids: Dictionary[String, bool] = { }
	var grace: Dictionary[StringName, bool] = { }
	var canonical: Dictionary[StringName, String] = { }
	var last_days: Dictionary[StringName, int] = { }
	var pending: Dictionary[StringName, bool] = { }
	for batch: CraftingBatch in commerce.crafting_batches:
		if (
			batch == null or batch.operation_id.is_empty() or batch.operation_id in operations
			or batch.container_id.is_empty() or not _profile_valid(batch.profile)
			or not batch.consumed or batch.inputs.is_empty() or batch.accepted_day < 1
			or batch.accepted_day > cycle.day_index or batch.ready_day != batch.accepted_day + 1
		):
			return false
		operations.append(batch.operation_id)
		var npc_id: StringName = batch.profile.npc_id
		if (
			pending.get(npc_id, false) or last_days.get(npc_id, 0) > batch.accepted_day
			or canonical.get(npc_id, batch.container_id) != batch.container_id
		):
			return false
		canonical[npc_id] = batch.container_id
		last_days[npc_id] = batch.accepted_day
		pending[npc_id] = not batch.completed
		if points.has(batch.container_id) and points[batch.container_id].profile != batch.profile:
			return false
		var previous_id: String = ""
		for item: CraftingInput in batch.inputs:
			if (
				item == null or item.entity_id.is_empty() or item.entity_id <= previous_id
				or consumed.has(item.entity_id) or live.has(item.entity_id) or not item.removed
				or item.definition == null or item.definition.resource_path.is_empty()
				or item.quantity < 1 or item.quantity > item.definition.maximum_stack
				or (item.full_blood and (item.definition.key != &"blood_flask" or not item.intact))
				or not _origin_valid(item, arrivals)
			):
				return false
			previous_id = item.entity_id
			consumed[item.entity_id] = true
		var grace_before: bool = grace.get(npc_id, false)
		if batch.signature != CraftingRecipeRules.signature(
			batch.container_id,
			batch.accepted_day,
			batch.profile,
			grace_before,
			batch.inputs,
		):
			return false
		var plan: CraftingPlan = CraftingRecipeRules.replay(batch.inputs, batch.recipes)
		if not plan.reason.is_empty():
			return false
		for gift: CraftingInput in plan.gifts:
			gift.removed = true
		if SaveDataCodec.encode(batch.gifts) != SaveDataCodec.encode(plan.gifts):
			return false
		if batch.first_failure != (batch.recipes.is_empty() and not grace_before):
			return false
		if batch.first_failure == batch.hint_text.is_empty():
			return false
		grace[npc_id] = grace_before or batch.first_failure
		if not _outputs_valid(batch, cycle.day_index, live, components, output_ids):
			return false
	for point_id: String in points:
		var npc_id: StringName = points[point_id].profile.npc_id
		if canonical.has(npc_id) and canonical[npc_id] != point_id:
			return false
	return true


static func _profile_valid(profile: DEF_CraftingProfile) -> bool:
	# Исторический долг требует личность/размещение, а не доступность нынешних рецептов.
	# Каталог для новой передачи проверяет CraftingQueries.available_reason.
	return (
		profile != null and not profile.resource_path.is_empty()
		and not profile.npc_id.is_empty() and profile.placement != null
	)


static func _origin_valid(
	item: CraftingInput,
	arrivals: Dictionary[String, PackageRegistrationRecord],
) -> bool:
	if item.source_package_id.is_empty():
		return item.source_history_id.is_empty()
	if item.source_history_id.is_empty():
		return true
	var arrival: PackageRegistrationRecord = arrivals.get(item.source_package_id)
	return (
		arrival != null and arrival.history_id == item.source_history_id
		and PackageHistoryId.parse(item.source_history_id) != null
	)
#endregion


#region Обещанное физическое исполнение
static func _outputs_valid(
	batch: CraftingBatch,
	day: int,
	live: Dictionary[String, String],
	components: Dictionary[String, Dictionary],
	ids: Dictionary[String, bool],
) -> bool:
	var definitions: Array[DEF_InventoryItem] = []
	for recipe: CraftingStep in batch.recipes:
		for index: int in recipe.output_quantity:
			definitions.append(recipe.output)
	if batch.recipes.is_empty() and not batch.first_failure:
		if (
			batch.trash_definition == null or batch.trash_definition.world_pickup_scene.is_empty()
			or batch.trash_quantity < 1 or batch.trash_quantity > 99
		):
			return false
		for index: int in batch.trash_quantity:
			definitions.append(batch.trash_definition)
	elif batch.trash_definition != null or batch.trash_quantity != 0:
		return false
	if batch.outputs.size() != definitions.size() or (batch.completed and day < batch.ready_day):
		return false
	var all_taken: bool = true
	for index: int in batch.outputs.size():
		var output: CraftingOutput = batch.outputs[index]
		if (
			output == null or output.entity_id != "%s/output/%d" % [batch.operation_id, index]
			or ids.has(output.entity_id) or output.definition != definitions[index]
			or (output.taken and not output.emitted) or (output.emitted and day < batch.ready_day)
			or (not output.emitted and live.has(output.entity_id))
		):
			return false
		ids[output.entity_id] = true
		if live.has(output.entity_id):
			var types: Dictionary = components[live[output.entity_id]]
			var stack: C_InventoryItem = types.get(C_InventoryItem) as C_InventoryItem
			if stack == null or stack.definition != output.definition or stack.quantity != 1:
				return false
		if not output.taken:
			all_taken = false
	if not batch.first_failure and batch.completed != all_taken:
		return false
	return true
#endregion
