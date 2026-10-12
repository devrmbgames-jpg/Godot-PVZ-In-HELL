extends GutTest
## Catalog authoring checks fingerprint, Inspector ownership and isolated native graph preservation.

const TOOL: Script = preload("res://addons/pvz_ai_tools/delivery_catalog_authoring_tool.gd")
const TOY: String = "res://content/domains/inventory/definitions/def_item_toy_block.tres"


#region Native preflight without writes
func test_native_append_preserves_cached_supply_and_every_existing_package() -> void:
	var checksum: String = FileAccess.get_sha256(TOOL.SUPPLY)
	var cached: DEF_Delivery = load(TOOL.SUPPLY) as DEF_Delivery
	var original: int = cached.maximum_batch_packages
	cached.maximum_batch_packages = 43
	var isolated: DEF_Delivery = ResourceLoader.load(
		TOOL.SUPPLY,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP,
	) as DEF_Delivery
	var source: DEF_InventoryItem = load(TOY) as DEF_InventoryItem
	var item: DEF_InventoryItem = source.duplicate(true) as DEF_InventoryItem
	item.key = &"catalog_test_new_key"
	var result: Dictionary = TOOL.call("_append_unique", isolated, item)
	assert_false(result.has("error"))
	var prepared: DEF_Delivery = result.definition
	assert_eq(prepared.maximum_batch_packages, original)
	assert_eq(cached.maximum_batch_packages, 43)
	assert_eq(prepared.packages.size(), cached.packages.size())
	for index: int in range(cached.packages.size()):
		assert_not_same(prepared.packages[index], cached.packages[index])
		assert_eq(prepared.packages[index].key, cached.packages[index].key)
		assert_eq(prepared.packages[index].description, cached.packages[index].description)
	assert_eq(prepared.order_catalog.size(), cached.order_catalog.size() + 1)
	assert_eq(prepared.order_catalog.back().key, item.key)
	assert_eq(FileAccess.get_sha256(TOOL.SUPPLY), checksum)
	cached.maximum_batch_packages = original


func test_refuses_changed_fingerprint_and_inspected_embedded_supply_resource() -> void:
	var checksum: String = FileAccess.get_sha256(TOOL.SUPPLY)
	assert_true(TOOL.preflight({ "fingerprint": "stale", "item": TOY }).has("error"))
	var cached: DEF_Delivery = load(TOOL.SUPPLY) as DEF_Delivery
	var params: Dictionary = { "fingerprint": checksum, "item": TOY }
	assert_true(TOOL.preflight(params, cached).has("error"))
	assert_true(TOOL.preflight(params, cached.packages[0]).has("error"))
	assert_eq(FileAccess.get_sha256(TOOL.SUPPLY), checksum)


func test_refuses_existing_key_wrong_type_and_escaping_paths() -> void:
	var checksum: String = FileAccess.get_sha256(TOOL.SUPPLY)
	for path: String in [
		TOOL.ITEM_ROOT + "def_item_axe.tres",
		TOOL.SUPPLY,
		TOY + "::embedded",
		TOOL.ITEM_ROOT + "../definitions/def_item_toy_block.tres",
		TOOL.ITEM_ROOT + "missing.tres",
	]:
		assert_true(TOOL.preflight({ "fingerprint": checksum, "item": path }).has("error"))
	assert_eq(FileAccess.get_sha256(TOOL.SUPPLY), checksum)
#endregion
