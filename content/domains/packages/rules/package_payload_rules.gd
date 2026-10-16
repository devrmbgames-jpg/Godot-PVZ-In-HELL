extends RefCounted
## Read-only remaining payload identity; native scene data is inspected without creating pickups.
class_name PackagePayloadRules


#region Remaining native item
## An empty shell or a committed loot remainder has no contents left inside the parcel.
## Catalog composition overrides legacy unpack scenes, including their immunity/effect metadata.
static func remaining_item(
	definition: DEF_Package,
	contents: C_PackageContents,
) -> DEF_InventoryItem:
	if contents == null or contents.released:
		return null
	if contents.selected_item != null:
		return contents.selected_item if contents.quantity > 0 else null
	if definition.unpack_scene == null or definition.content_quantity <= 0:
		return null
	return _native_item(definition.unpack_scene)


static func _native_item(scene: PackedScene) -> DEF_InventoryItem:
	var state: SceneState = scene.get_state()
	var visited: Array[SceneState] = []
	while state != null and not visited.has(state):
		visited.append(state)
		if state.get_node_count() == 0:
			return null
		for index: int in state.get_node_property_count(0):
			if state.get_node_property_name(0, index) != &"component_resources":
				continue
			var value: Variant = state.get_node_property_value(0, index)
			if not value is Array:
				return null
			for component: Variant in value as Array:
				var item: C_InventoryItem = component as C_InventoryItem
				if item != null:
					return item.definition if item.quantity > 0 else null
			# A derived array replaces its base: do not recover a removed InventoryItem.
			return null
		var base: SceneState = state.get_base_scene_state()
		if base == null:
			var inherited: PackedScene = state.get_node_instance(0)
			base = inherited.get_state() if inherited != null else null
		state = base
	return null
#endregion
