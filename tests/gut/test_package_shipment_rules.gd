extends GutTest
## Detached shipments align actual quantities, native capacity, mass and retry determinism.

const TOY: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_toy_block.tres"
)
const BARREL: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_acid_barrel.tres"
)
const SCYTHE: DEF_InventoryItem = preload(
	"res://content/domains/inventory/definitions/def_item_scythe.tres"
)
const PROFILES: Array[DEF_PackagePacking] = [
	preload("res://content/domains/packages/definitions/def_packing_small_a.tres"),
	preload("res://content/domains/packages/definitions/def_packing_small_b.tres"),
	preload("res://content/domains/packages/definitions/def_packing_medium.tres"),
	preload("res://content/domains/packages/definitions/def_packing_large.tres"),
	preload("res://content/domains/packages/definitions/def_packing_barrel.tres"),
	preload("res://content/domains/packages/definitions/def_packing_long.tres"),
]


#region Actual quantity and physical facts
func test_single_toy_and_bulk_keep_quantity_and_use_actual_combined_mass() -> void:
	var single: PackageShipmentPlan = _fixed(TOY, 1)
	var bulk: PackageShipmentPlan = _fixed(TOY, 8)
	assert_not_null(single)
	assert_not_null(bulk)
	assert_same(single.item(), TOY)
	assert_eq(single.quantity(), 1)
	assert_eq(single.packing().key, &"small_b")
	assert_eq(bulk.quantity(), 8)
	assert_eq(bulk.packing().key, &"large")
	assert_almost_eq(single.empty_mass_kg(), 0.7, 0.0001)
	assert_almost_eq(single.gross_mass_kg(), 1.2, 0.0001)
	assert_almost_eq(bulk.gross_mass_kg(), 6.0, 0.0001)
	assert_has(single.packing().scene_variants, single.scene_path())
	assert_has(bulk.packing().scene_variants, bulk.scene_path())


func test_large_indivisible_items_choose_their_real_shells() -> void:
	var barrel: PackageShipmentPlan = _fixed(BARREL, 1)
	var scythe: PackageShipmentPlan = _fixed(SCYTHE, 1)
	assert_not_null(barrel)
	assert_not_null(scythe)
	assert_eq(barrel.packing().key, &"barrel")
	assert_eq(scythe.packing().key, &"long")
	assert_almost_eq(barrel.gross_mass_kg(), 20.5, 0.0001)
	assert_almost_eq(scythe.gross_mass_kg(), 5.5, 0.0001)
	assert_null(_fixed(BARREL, 2), "The authored single-unit limit cannot be clamped")
	assert_null(_fixed(SCYTHE, 2))


func test_explicit_unsupported_counts_fail_without_substitution() -> void:
	for quantity: int in [-1, 0, 9, 100]:
		assert_null(_fixed(TOY, quantity))
	var profiles: Array[DEF_PackagePacking] = [PROFILES[0]]
	assert_null(PackageShipmentRules.for_quantity(BARREL, 1, profiles, 17, "parcel", 1))
	assert_null(PackageShipmentRules.choose(BARREL, profiles, 17, "parcel", 1))
#endregion


#region Bounded deterministic preparation
func test_quantity_selection_excludes_capacity_gaps_and_can_choose_real_bulk() -> void:
	var small: DEF_PackagePacking = PROFILES[0].duplicate() as DEF_PackagePacking
	small.inner_size_m = Vector3(0.6, 0.6, 0.6)
	small.usable_volume_ratio = 1.0
	small.maximum_quantity = 4
	var large: DEF_PackagePacking = PROFILES[3].duplicate() as DEF_PackagePacking
	var profiles: Array[DEF_PackagePacking] = [large, small]
	var saw_bulk: bool = false
	var saw_small: bool = false
	for world_seed: int in range(32):
		var plan: PackageShipmentPlan = PackageShipmentRules.choose(
			TOY,
			profiles,
			world_seed,
			"quantity/gap",
			1,
		)
		assert_not_null(plan)
		assert_has([1, 2, 3, 4, 8], plan.quantity())
		assert_true(PackagePackingRules.accepts(plan.packing(), TOY.cargo_profile, plan.quantity()))
		saw_bulk = saw_bulk or plan.quantity() == 8
		saw_small = saw_small or plan.quantity() <= 4
	assert_true(saw_bulk)
	assert_true(saw_small)


func test_retry_and_catalog_reordering_preserve_plan_without_consuming_global_rng() -> void:
	var profiles: Array[DEF_PackagePacking] = PROFILES.duplicate()
	var first: PackageShipmentPlan = PackageShipmentRules.choose(TOY, profiles, 507, "retry", 2)
	profiles.reverse()
	seed(1049)
	var expected: int = randi()
	seed(1049)
	var retry: PackageShipmentPlan = PackageShipmentRules.choose(TOY, profiles, 507, "retry", 2)
	assert_eq(retry.quantity(), first.quantity())
	assert_same(retry.item(), first.item())
	assert_same(retry.packing(), first.packing())
	assert_eq(retry.scene_path(), first.scene_path())
	assert_eq(retry.gross_mass_kg(), first.gross_mass_kg())
	assert_eq(randi(), expected)


func test_variant_order_does_not_change_selection_or_mutate_authored_profiles() -> void:
	var packing: DEF_PackagePacking = PROFILES[1].duplicate() as DEF_PackagePacking
	packing.scene_variants = [PROFILES[1].scene_variants[0], PROFILES[0].scene_variants[0]]
	var profiles: Array[DEF_PackagePacking] = [packing]
	var first: PackageShipmentPlan = PackageShipmentRules.for_quantity(
		TOY,
		1,
		profiles,
		17,
		"variants",
		1,
	)
	packing.scene_variants.reverse()
	var before: Array[String] = packing.scene_variants.duplicate()
	var retry: PackageShipmentPlan = PackageShipmentRules.for_quantity(
		TOY,
		1,
		profiles,
		17,
		"variants",
		1,
	)
	assert_eq(first.scene_path(), retry.scene_path())
	assert_eq(packing.scene_variants, before)
	assert_eq(TOY.cargo_profile.maximum_shipment_quantity, 8)
	assert_eq(PROFILES[1].scene_variants.size(), 1)
	assert_eq(PROFILES[1].inner_size_m, Vector3(0.42, 0.37, 0.42))


func test_invalid_identity_ambiguous_profiles_and_excessive_inputs_reject() -> void:
	assert_null(PackageShipmentRules.choose(null, PROFILES, 17, "parcel", 1))
	assert_null(PackageShipmentRules.choose(TOY, PROFILES, 17, "", 1))
	assert_null(PackageShipmentRules.choose(TOY, PROFILES, 17, "parcel", 0))
	assert_null(PackageShipmentRules.choose(TOY, [], 17, "parcel", 1))
	var profiles: Array[DEF_PackagePacking] = [PROFILES[1], PROFILES[1]]
	assert_null(PackageShipmentRules.choose(TOY, profiles, 17, "parcel", 1))
	profiles.resize(PackagePackingRules.MAX_PROFILES + 1)
	assert_null(PackageShipmentRules.choose(TOY, profiles, 17, "parcel", 1))
#endregion


#region Native authored fixtures
func _fixed(item: DEF_InventoryItem, quantity: int) -> PackageShipmentPlan:
	return PackageShipmentRules.for_quantity(item, quantity, PROFILES, 17, "shipment", 1)
#endregion
