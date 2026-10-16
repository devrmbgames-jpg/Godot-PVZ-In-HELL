extends GutTest
## Authored reaction materials match the actual native item effect and physical cargo facts.

const ITEMS_ROOT: String = "res://content/domains/inventory/definitions/"


#region Native supernatural capability
func test_every_authored_item_uses_the_same_effect_definition_as_its_native_body() -> void:
	var checked_items: int = 0
	var supernatural_items: int = 0
	for filename: String in DirAccess.get_files_at(ITEMS_ROOT):
		if not filename.begins_with("def_item_") or not filename.ends_with(".tres"):
			continue
		var item: DEF_InventoryItem = load(ITEMS_ROOT + filename) as DEF_InventoryItem
		var scene: PackedScene = load(item.world_pickup_scene) as PackedScene
		var body: Entity = autofree(scene.instantiate()) as Entity
		assert_not_null(body, String(item.key))
		if body == null:
			continue
		var native_effect: DEF_ReceiverEffect = null
		for component: Component in body.component_resources:
			if component is C_ReceiverEffect:
				native_effect = (component as C_ReceiverEffect).definition
		assert_same(item.receiver_effect, native_effect, String(item.key))
		checked_items += 1
		if native_effect != null:
			supernatural_items += 1
	assert_gt(checked_items, 0)
	assert_eq(supernatural_items, 2, "Both native artifact alignments must be exercised")


func test_holy_and_unholy_are_distinct_typed_effects_despite_the_same_shopping_category() -> void:
	var holy: DEF_InventoryItem = _item("holy_artifact")
	var unholy: DEF_InventoryItem = _item("unholy_artifact")
	assert_eq(holy.categories, unholy.categories)
	assert_eq(holy.receiver_effect.alignment, DEF_ReceiverEffect.Alignment.HOLY)
	assert_eq(unholy.receiver_effect.alignment, DEF_ReceiverEffect.Alignment.UNHOLY)
	assert_false(holy.destroyed_by_fire)
	assert_false(unholy.destroyed_by_fire)
#endregion


#region Authored material eligibility
func test_owner_named_fire_destructible_materials_include_liquids_and_virtual_supplies() -> void:
	for key: String in [
		"acid_barrel",
		"blood_barrel",
		"blood_flask",
		"work_clothes",
		"toy_block",
		"food",
		"med",
	]:
		assert_true(_item(key).destroyed_by_fire, key)
	assert_false(_item("food").requires_world_body())
	assert_false(_item("med").requires_world_body())
	assert_true(_item("work_clothes").requires_world_body())


func test_material_destruction_is_independent_of_cargo_hazard_and_weapon_category() -> void:
	var acid: DEF_InventoryItem = _item("acid_barrel")
	var blood: DEF_InventoryItem = _item("blood_flask")
	var fire: DEF_InventoryItem = _item("fire_flask")
	var axe: DEF_InventoryItem = _item("axe")
	assert_eq(acid.cargo_profile.hazards, DEF_ItemCargo.Hazard.TOXIC)
	assert_eq(blood.cargo_profile.hazards, DEF_ItemCargo.Hazard.NONE)
	assert_true(bool(fire.cargo_profile.hazards & DEF_ItemCargo.Hazard.FLAMMABLE))
	assert_true(acid.destroyed_by_fire)
	assert_true(blood.destroyed_by_fire)
	assert_true(fire.destroyed_by_fire)
	assert_true(bool(axe.categories & DEF_InventoryItem.Category.WEAPON))
	assert_false(axe.destroyed_by_fire)
#endregion


#region Catalog fixture lookup
func _item(key: String) -> DEF_InventoryItem:
	return load(ITEMS_ROOT + "def_item_" + key + ".tres") as DEF_InventoryItem
#endregion
