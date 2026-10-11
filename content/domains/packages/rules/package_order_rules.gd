extends RefCounted
## Selects orderable catalog categories before items, using one explicit deterministic decision.
class_name PackageOrderRules

## Bound on authored supply catalog work; category bits are shared inventory data.
const MAX_CATALOG_ITEMS: int = 128
const CATEGORIES: Array[int] = [
	DEF_InventoryItem.Category.WEAPON,
	DEF_InventoryItem.Category.CLOTHING,
	DEF_InventoryItem.Category.ARTIFACT,
	DEF_InventoryItem.Category.REAGENT,
	DEF_InventoryItem.Category.TOY,
	DEF_InventoryItem.Category.VALUABLE,
]


#region Canonical category selection
## Missing preferences fall back to available categories; an empty catalog yields no new order.
static func choose(
	catalog: Array[DEF_InventoryItem],
	weights: Dictionary[int, float],
	world_seed: int,
	person_id: String,
	day_index: int,
	package_id: String,
) -> DEF_InventoryItem:
	if (
		catalog.size() > MAX_CATALOG_ITEMS or person_id.is_empty()
		or package_id.is_empty() or day_index < 1
	):
		return null
	var items: Array[DEF_InventoryItem] = []
	var validated: Array[DEF_InventoryItem] = []
	var counts: Dictionary[StringName, int] = { }
	for item: DEF_InventoryItem in catalog:
		if is_orderable(item):
			counts[item.key] = counts.get(item.key, 0) + 1
			validated.append(item)
	for item: DEF_InventoryItem in validated:
		if counts[item.key] == 1:
			items.append(item)
	if items.is_empty():
		return null
	items.sort_custom(_item_before)

	var available: Array[int] = []
	var preferred: Array[int] = []
	var total_weight: float = 0.0
	for category: int in CATEGORIES:
		if not _has_category(items, category):
			continue
		available.append(category)
		var weight: float = weights.get(category, 0.0)
		if is_finite(weight) and weight > 0.0:
			preferred.append(category)
			total_weight += weight
	if available.is_empty():
		return null
	var random: RandomNumberGenerator = DecisionRandomRules.generator(
		world_seed,
		person_id,
		day_index,
		"npc/order_item/" + package_id,
	)
	var selected_category: int = available[random.randi_range(0, available.size() - 1)]
	if not preferred.is_empty():
		var roll: float = random.randf() * total_weight
		selected_category = preferred.back()
		for category: int in preferred:
			roll -= weights[category]
			if roll < 0.0:
				selected_category = category
				break
	var candidates: Array[DEF_InventoryItem] = []
	for item: DEF_InventoryItem in items:
		if item.categories & selected_category:
			candidates.append(item)
	return candidates[random.randi_range(0, candidates.size() - 1)]


## Catalog references must be authored definitions with a real physical entity scene.
static func is_orderable(item: DEF_InventoryItem) -> bool:
	if (
		item == null or item.key == &"" or item.categories <= 0
		or not GameplayResourcePaths.is_definition_path(item.resource_path)
		or not GameplayResourcePaths.is_entity_scene_path(item.world_pickup_scene)
		or not ResourceLoader.exists(item.world_pickup_scene, "PackedScene")
	):
		return false
	var scene: PackedScene = load(item.world_pickup_scene) as PackedScene
	var state: SceneState = scene.get_state()
	if state.get_node_count() == 0 or state.get_node_type(0) != &"RigidBody3D":
		return false
	var entity_script: Script = null
	for index: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, index) == &"script":
			entity_script = state.get_node_property_value(0, index) as Script
	while entity_script != null:
		if entity_script == (Entity as Script):
			return true
		entity_script = entity_script.get_base_script()
	return false


static func _has_category(items: Array[DEF_InventoryItem], category: int) -> bool:
	for item: DEF_InventoryItem in items:
		if item.categories & category:
			return true
	return false


static func _item_before(first: DEF_InventoryItem, second: DEF_InventoryItem) -> bool:
	return String(first.key) < String(second.key)
#endregion
