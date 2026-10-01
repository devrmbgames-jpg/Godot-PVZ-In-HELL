extends Observer
class_name O_InventoryLifecycle


func setup() -> void:
	_world.entity_disabled.connect(InventoryService.entity_unavailable)
	_world.entity_removed.connect(InventoryService.entity_unavailable)


func sub_observers() -> Array[Array]:
	return [[q.with_all([C_InventoryItem]).on_added(), _bind_item, true], [q.with_all([C_Inventory, C_Death]).on_added(), _on_death]]


func _bind_item(_event: Variant, item: Entity, _payload: Variant = null) -> void:
	if not item.relationship_removed.is_connected(InventoryService.ownership_removed):
		item.relationship_removed.connect(InventoryService.ownership_removed)


func _on_death(_event: Variant, owner: Entity, _payload: Variant = null) -> void:
	cmd.add_custom(InventoryService.clear_owner.bind(owner))
