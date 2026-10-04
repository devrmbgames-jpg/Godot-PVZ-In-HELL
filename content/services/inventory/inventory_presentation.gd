extends RefCounted
class_name InventoryPresentation


static func debug_text(owner: Entity) -> String:
	if not EntityAvailability.contains(owner, ECS.world):
		return ""

	var inventory: C_Inventory = owner.get_component(C_Inventory) as C_Inventory
	if inventory == null:
		return ""

	var owned: Array[Entity] = InventoryService.items(owner)
	var labels: PackedStringArray = []
	for item: Entity in owned:
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		labels.append("%s ×%d" % [state.definition.display_name, state.quantity])
	return "[Tab] ИНВЕНТАРЬ %d / %d · %s\nУсловие: %s · задача: подберите и используйте расходник" % [owned.size(), inventory.maximum_stacks, ", ".join(labels) if not labels.is_empty() else "пусто", "эффект выполняется" if inventory.use_in_progress else "готов"]
