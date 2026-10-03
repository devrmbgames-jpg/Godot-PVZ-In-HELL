extends "res://tests/gut/test_district_population.gd"
## Community participation, inventory conservation and street dialogue resource regression.

#region Community acceptance
## Off-map participation keeps owned items and returning does not grant another stack.
func test_absence_preserves_owned_inventory() -> void:
	_world.add_observer(O_InventoryLifecycle.new())
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var food: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_npc_meat.tres") as DEF_InventoryItem
	assert_true(InventoryService.grant(body, food, 2))
	var item: Entity = InventoryService.items(body)[0]
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE)
	assert_same(InventoryService.owner_for(item), body)
	assert_true(_world.entity_to_archetype.has(item))
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	assert_eq(InventoryService.items(body).size(), 1)
	assert_eq((item.get_component(C_InventoryItem) as C_InventoryItem).quantity, 2)

## Merchants retain their catalog and replacements have distinct names and aliases for future cases.
func test_replacement_is_new_person_with_existing_address_alias() -> void:
	var first: NpcRecord = _district.people[0]
	var merchant: NpcRecord = _district.people[7]
	var original_name: String = merchant.display_name
	var original_alias: StringName = merchant.recipient_key
	DistrictPopulationService.mark_dead(first, DistrictPopulationService.body_for(first.npc_id), 1)
	DistrictPopulationService.mark_dead(merchant, DistrictPopulationService.body_for(merchant.npc_id), 1)
	DistrictPopulationService.prepare_morning(3)
	var replacement: NpcRecord = _district.people.back()
	assert_true(replacement.profile.merchant)
	assert_ne(replacement.display_name, original_name)
	assert_eq(replacement.recipient_key, original_alias)
	var body: E_DistrictNpc = DistrictPopulationService.body_for(replacement.npc_id)
	assert_not_null(body.get_component(C_Trader) as C_Trader)
	assert_not_null((body.get_component(C_Trader) as C_Trader).profile)
	assert_eq(replacement.memories.size(), 0)

## The ordinary inventory use path consumes meat once rather than granting food from a corpse flag.
func test_npc_consumes_real_meat_once() -> void:
	var body: E_DistrictNpc = DistrictPopulationService.body_for(_district.people[0].npc_id)
	var food: DEF_InventoryItem = load("res://content/definitions/gameplay/inventory/def_item_npc_meat.tres") as DEF_InventoryItem
	assert_true(InventoryService.grant(body, food, 1))
	var hunger: C_Hunger = body.get_component(C_Hunger) as C_Hunger
	hunger.value = 50.0
	var item: Entity = InventoryService.items(body)[0]
	assert_true(InventoryService.use(body, item))
	assert_lt(hunger.value, 50.0)
	assert_eq(InventoryService.items(body).size(), 0)
	assert_false(InventoryService.use(body, item))

## The authored street branches compile through pinned Dialogue Manager.
func test_street_dialogue_resource_has_explicit_entry_cues() -> void:
	var resource: DialogueResource = load("res://content/dialogue/npc_street.dialogue") as DialogueResource
	assert_not_null(resource)
	if resource != null:
		assert_true(resource.cues.has("street"))
		assert_true(resource.cues.has("provocation"))
#endregion
