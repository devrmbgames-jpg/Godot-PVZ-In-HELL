extends "res://tests/gut/test_npc_life_cycle.gd"
## Реальные стеки, terminal disable и возврат личности при обоих порядках observers.

const MED_PATH: String = "res://content/domains/inventory/definitions/def_item_med.tres"


#region Production inventory integration
func before_each() -> void:
	super.before_each()
	_world.add_observer(O_InventoryLifecycle.new())


func _active_owner() -> E_DistrictNpc:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	assert_true(body.has_component(C_Inventory))
	assert_true(
		DistrictPopulationService.set_placement(
			person,
			body,
			NpcRecord.Placement.STREET,
			&"belongings_test",
			false,
			NpcPopulationQueries.position_for(person.home_id, true) + Vector3(0.0, 0.0, 5.0),
		)
	)
	return body


func _owned_med(body: E_DistrictNpc) -> Entity:
	assert_true(InventoryService.grant(body, load(MED_PATH) as DEF_InventoryItem, 2))
	var items: Array[Entity] = InventoryService.items(body)
	assert_eq(items.size(), 1)
	return items[0]


func _dropped_stack() -> Array[Entity]:
	var found: Array[Entity] = []
	for item: Entity in _world.query.with_all([C_InventoryItem]).execute():
		var state: C_InventoryItem = item.get_component(C_InventoryItem) as C_InventoryItem
		if (
			state.definition.resource_path == MED_PATH and state.quantity == 2
			and InventoryService.owner_for(item) == null
		):
			found.append(item)
	return found


func _assert_actual_death_and_return_preserve_the_one_drop() -> void:
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var body: E_DistrictNpc = _active_owner()
	var source: Entity = _owned_med(body)
	var source_id: String = source.id
	_kill(person)
	_world.flush_command_buffers()
	assert_false(body.enabled)
	assert_false(_world.entity_to_archetype.has(source))
	var drops: Array[Entity] = _dropped_stack()
	assert_eq(drops.size(), 1, "Actual carried quantity must become a physical pickup")
	if drops.size() != 1:
		return
	var pickup_id: String = drops[0].id
	assert_ne(pickup_id, source_id, "Existing death-drop policy replaces the virtual stack")
	_morning(3)
	assert_true(InventoryService.items(body).is_empty())
	assert_eq(_dropped_stack().size(), 1)
	assert_eq(_dropped_stack()[0].id, pickup_id)
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 3)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	assert_true(WorldSnapshotService.restore(AutosaveStore.read(SAVE_PATH), _root))
	assert_eq(_dropped_stack().size(), 1)
	assert_eq(_dropped_stack()[0].id, pickup_id)
	person = NpcPopulationQueries.person_for(person.npc_id)
	_kill(person)
	assert_eq(_dropped_stack().size(), 1, "Return does not recreate the carried med stack")
	assert_eq(_dropped_stack()[0].id, pickup_id)


func test_inventory_observer_after_district_death_preserves_carried_drop_once() -> void:
	_assert_actual_death_and_return_preserve_the_one_drop()


func test_inventory_observer_before_district_death_preserves_carried_drop_once() -> void:
	var lifecycle: O_DistrictLifecycle = null
	for observer: Observer in _world.observers:
		if observer is O_DistrictLifecycle:
			lifecycle = observer as O_DistrictLifecycle
	assert_not_null(lifecycle)
	_world.remove_observer(lifecycle)
	_world.add_observer(O_DistrictLifecycle.new())
	_assert_actual_death_and_return_preserve_the_one_drop()


func test_buffered_inventory_death_keeps_the_stack_until_drop_after_native_disable() -> void:
	for observer: Observer in _world.observers:
		if observer is O_InventoryLifecycle:
			observer.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_assert_actual_death_and_return_preserve_the_one_drop()


func test_living_home_and_morning_keep_owned_stack_identity_and_quantity() -> void:
	var body: E_DistrictNpc = _active_owner()
	var person: NpcRecord = NpcPopulationQueries.person_for(&"npc/3")
	var item: Entity = _owned_med(body)
	var item_id: String = item.id
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.HOME))
	assert_false(body.enabled)
	assert_same(InventoryService.owner_for(item), body)
	_morning(2)
	assert_same(InventoryService.owner_for(item), body)
	_active_owner()
	var items: Array[Entity] = InventoryService.items(body)
	assert_eq(items.size(), 1)
	assert_eq(items[0].id, item_id)
	assert_eq((items[0].get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)
	assert_true(_dropped_stack().is_empty())
#endregion
