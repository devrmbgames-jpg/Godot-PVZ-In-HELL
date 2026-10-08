extends Observer
## Связывает очистку владения со смертью, удалением и отключением; живые отсутствующие NPC сохраняют вещи.
class_name O_InventoryLifecycle


#region Lifecycle subscriptions
## Подписывает текущий World на недоступность сущностей.
func setup() -> void:
	_world.entity_disabled.connect(_on_disabled)
	_world.entity_removed.connect(InventoryService.entity_unavailable)


## Привязывает снятие владения и однократную обработку смерти владельца.
func sub_observers() -> Array[Array]:
	return [[q.with_all([C_InventoryItem]).on_added(), _bind_item, true], [q.with_all([C_Inventory, C_Death]).on_added(), _on_death]]


func _bind_item(_event: Variant, item: Entity, _payload: Variant = null) -> void:
	if not item.relationship_removed.is_connected(InventoryService.ownership_removed):
		item.relationship_removed.connect(InventoryService.ownership_removed)


func _on_death(_event: Variant, owner: Entity, _payload: Variant = null) -> void:
	var inventory: C_Inventory = owner.get_component(C_Inventory) as C_Inventory
	var death: C_Death = owner.get_component(C_Death) as C_Death
	cmd.add_custom(_death_inventory.bind(weakref(owner), inventory, death))


func _on_disabled(owner: Entity) -> void:
	if owner.has_component(C_NpcIdentity) and not owner.has_component(C_Death):
		return

	InventoryService.entity_unavailable(owner)
#endregion


#region Captured death cleanup
func _death_inventory(owner_reference: WeakRef, inventory: C_Inventory, death: C_Death) -> void:
	# The owner may disappear or its restored Components may replace the queued context.
	# Registered disabled owners still need terminal cleanup.
	# Resolve the weak reference inside the callback: typed Callable arguments reject
	# a freed Entity before the function's own lifetime checks can execute.
	var owner: Entity = owner_reference.get_ref() as Entity
	if owner == null or not _world.entity_to_archetype.has(owner) or owner.is_queued_for_deletion():
		return
	if owner.get_component(C_Inventory) != inventory or owner.get_component(C_Death) != death:
		return

	if owner.has_component(C_NpcIdentity):
		InventoryDropService.release_on_death(owner)
	InventoryService.clear_owner(owner)
#endregion
