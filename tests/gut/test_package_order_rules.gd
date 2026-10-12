extends GutTest
## Category weights, catalog growth/fallback and deterministic order manifests without global RNG.

const ITEMS_ROOT: String = "res://content/domains/inventory/definitions/"


#region Category decisions
## Original physical entries and the authored toy are orderable; case paths remain.
func test_authored_catalog_includes_toy_and_preserves_case_paths() -> void:
	var supply_path: String = (
		"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
	)
	var supply: DEF_Delivery = load(supply_path) as DEF_Delivery
	assert_eq(supply.order_catalog.size(), 16)
	assert_true(_item("toy_block") in supply.order_catalog)
	for item: DEF_InventoryItem in supply.order_catalog:
		assert_true(PackageOrderRules.is_orderable(item), String(item.key))
	var expected: PackedStringArray = [
		"Books",
		"Bottles",
		"Equipment",
		"Glass",
		"Oil",
		"Cells",
		"Clothes",
		"Tools",
	]
	assert_eq(supply.packages.size(), expected.size())
	for index: int in expected.size():
		assert_eq(supply.packages[index].resource_path, supply_path + "::" + expected[index])


func _item(key: String) -> DEF_InventoryItem:
	return load(ITEMS_ROOT + "def_item_" + key + ".tres") as DEF_InventoryItem


## Reordering the authored catalog cannot change one person's committed order decision.
func test_canonical_choice_is_repeatable_and_uses_no_global_randomness() -> void:
	var catalog: Array[DEF_InventoryItem] = [
		_item("axe"),
		_item("fire_flask"),
		_item("holy_artifact"),
	]
	var weights: Dictionary[int, float] = { DEF_InventoryItem.Category.WEAPON: 3.0 }
	var chosen: DEF_InventoryItem = PackageOrderRules.choose(
		catalog,
		weights,
		67,
		"npc/2",
		4,
		"case/8",
	)
	assert_same(chosen, catalog[0])
	catalog.reverse()
	seed(991)
	var expected: int = randi()
	seed(991)
	assert_same(PackageOrderRules.choose(catalog, weights, 67, "npc/2", 4, "case/8"), chosen)
	assert_eq(randi(), expected, "Order decisions never consume global random state")


## Adding another authored artifact works immediately without editing an NPC or the selection code.
func test_new_catalog_items_participate_by_category() -> void:
	var catalog: Array[DEF_InventoryItem] = [_item("axe"), _item("holy_artifact")]
	var weights: Dictionary[int, float] = { DEF_InventoryItem.Category.ARTIFACT: 1.0 }
	var counts: Dictionary[StringName, int] = { }
	catalog.append(_item("unholy_artifact"))
	for day_index: int in range(1, 97):
		var chosen: DEF_InventoryItem = PackageOrderRules.choose(
			catalog,
			weights,
			6,
			"npc/9",
			day_index,
			"case/2",
		)
		assert_true(bool(chosen.categories & DEF_InventoryItem.Category.ARTIFACT))
		counts[chosen.key] = counts.get(chosen.key, 0) + 1
	assert_true(counts.has(&"holy_artifact"))
	assert_true(counts.has(&"unholy_artifact"))


## Category probability is independent of the number of items listed within that category.
func test_weighted_categories_do_not_gain_probability_from_catalog_item_count() -> void:
	var catalog: Array[DEF_InventoryItem] = [
		_item("axe"),
		_item("scythe"),
		_item("throwing_knife"),
		_item("spiked_chains"),
		_item("holy_artifact"),
	]
	var weights: Dictionary[int, float] = {
		DEF_InventoryItem.Category.WEAPON: 1.0,
		DEF_InventoryItem.Category.ARTIFACT: 9.0,
	}
	var artifacts: int = 0
	for day_index: int in range(1, 257):
		var chosen: DEF_InventoryItem = PackageOrderRules.choose(
			catalog,
			weights,
			7,
			"npc/1",
			day_index,
			"case/1",
		)
		if chosen.categories & DEF_InventoryItem.Category.ARTIFACT:
			artifacts += 1
	assert_gt(artifacts, 205, "9:1 category preference must not become 9:4 item preference")
	assert_lt(artifacts, 256)


## Unavailable clothing/toys and invalid entries degrade to the available real catalog.
func test_missing_categories_and_empty_preferences_fall_back_without_invalid_orders() -> void:
	var catalog: Array[DEF_InventoryItem] = [_item("axe"), _item("holy_artifact"), null]
	var missing: Dictionary[int, float] = { DEF_InventoryItem.Category.CLOTHING: 10.0 }
	var neutral: Dictionary[int, float] = { }
	var seen: Dictionary[StringName, bool] = { }
	for day_index: int in range(1, 33):
		var chosen: DEF_InventoryItem = PackageOrderRules.choose(
			catalog,
			missing,
			89,
			"npc/1",
			day_index,
			"case/1",
		)
		assert_true(chosen in catalog)
		assert_true(PackageOrderRules.is_orderable(chosen))
		chosen = PackageOrderRules.choose(catalog, neutral, 89, "npc/1", day_index, "case/1")
		seen[chosen.key] = true
	assert_eq(seen.size(), 2)
	assert_null(PackageOrderRules.choose([], missing, 89, "npc/1", 1, "case/1"))


## Repeated keys are rejected as ambiguous rather than gaining catalog-order-dependent priority.
func test_invalid_and_duplicate_catalog_entries_are_excluded() -> void:
	var invalid: DEF_InventoryItem = DEF_InventoryItem.new()
	invalid.key = &"unpublished"
	invalid.categories = DEF_InventoryItem.Category.WEAPON
	invalid.world_pickup_scene = _item("axe").world_pickup_scene
	var valid: DEF_InventoryItem = _item("holy_artifact")
	var catalog: Array[DEF_InventoryItem] = [_item("axe"), _item("axe"), valid, invalid]
	var weights: Dictionary[int, float] = { DEF_InventoryItem.Category.WEAPON: 2.0 }
	assert_false(PackageOrderRules.is_orderable(invalid))
	assert_same(PackageOrderRules.choose(catalog, weights, 9, "npc/8", 2, "case/8"), valid)


## An incomplete durable batch is rejected instead of silently returning to legacy contents.
func test_committed_manifest_requires_item_paths_and_preserves_explicit_legacy_entries() -> void:
	var batch: ReceivingBatch = ReceivingBatch.new()
	batch.day_index = 3
	batch.package_keys = ["one", "two"]
	batch.package_scenes = ["a", "b"]
	batch.order_item_paths = [_item("axe").resource_path, ""]
	var data: Dictionary = SaveDataCodec.encode(batch) as Dictionary
	var restored: ReceivingBatch = SaveDataCodec.decode(data) as ReceivingBatch
	assert_not_null(restored)
	assert_eq(restored.order_item_paths, batch.order_item_paths)
	(data.fields as Dictionary).erase("order_item_paths")
	assert_null(SaveDataCodec.decode(data))
#endregion
