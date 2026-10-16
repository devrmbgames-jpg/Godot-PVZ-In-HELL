extends GutTest
## Shipment capacity boundaries: one small item, real bulk, a large unit, invalid data and ties.

const PACKAGE_SCENE: String = "res://content/domains/packages/entities/package.tscn"
const LARGE_SCENE: String = "res://content/domains/packages/entities/package_big.tscn"


#region Actual contents determine capacity
## A small order stays small; bulk capacity never adds units to justify a large shell.
func test_small_item_and_bulk_use_different_shells_without_changing_cargo() -> void:
	var cargo: DEF_ItemCargo = _cargo(Vector3(0.1, 0.1, 0.1), 0.25)
	var small: DEF_PackagePacking = _small()
	var large: DEF_PackagePacking = _large()
	var profiles: Array[DEF_PackagePacking] = [large, small]
	assert_same(PackagePackingRules.choose(profiles, cargo, 1), small)
	assert_false(PackagePackingRules.accepts(large, cargo, 1))
	assert_null(PackagePackingRules.choose(profiles, cargo, 5), "No shell permits this quantity")
	assert_same(PackagePackingRules.choose(profiles, cargo, 8), large)
	assert_eq(cargo.unit_mass_kg, 0.25)
	assert_eq(cargo.unit_size_m, Vector3(0.1, 0.1, 0.1))
	assert_eq(large.minimum_small_quantity, 8)


## One sufficiently large unit can justify a large shell; several small units cannot bypass bulk.
func test_one_large_unit_bypasses_bulk_minimum_only_when_it_fits() -> void:
	var barrel: DEF_ItemCargo = _cargo(Vector3(0.7, 0.45, 0.45), 20.0)
	barrel.phase = DEF_ItemCargo.Phase.LIQUID
	var profiles: Array[DEF_PackagePacking] = [_small(), _large()]
	assert_same(PackagePackingRules.choose(profiles, barrel, 1), profiles[1])
	assert_null(PackagePackingRules.choose(profiles, barrel, 2))
	assert_true(PackagePackingRules.accepts(profiles[1], barrel, 1))
	barrel.unit_size_m = Vector3(1.1, 0.1, 0.1)
	assert_null(PackagePackingRules.choose(profiles, barrel, 1), "Long units still need clearance")


## Orthogonal orientation may change; an oversized axis is rejected even at very low volume.
func test_rotated_unit_envelope_fits_without_treating_volume_as_shape() -> void:
	var shell: DEF_PackagePacking = _small()
	var cargo: DEF_ItemCargo = _cargo(Vector3(0.2, 0.45, 0.3), 1.0)
	assert_true(PackagePackingRules.accepts(shell, cargo, 1))
	cargo.unit_size_m = Vector3(0.51, 0.01, 0.01)
	assert_false(PackagePackingRules.accepts(shell, cargo, 1))


## Both gross mass and usable padded volume constrain the already selected quantity.
func test_gross_mass_and_padding_volume_are_independent_limits() -> void:
	var shell: DEF_PackagePacking = _small()
	var cargo: DEF_ItemCargo = _cargo(Vector3(0.25, 0.25, 0.25), 1.0)
	shell.maximum_quantity = 99
	assert_true(PackagePackingRules.accepts(shell, cargo, 2))
	assert_false(PackagePackingRules.accepts(shell, cargo, 3), "Padding consumes real capacity")
	cargo.unit_size_m = Vector3(0.1, 0.1, 0.1)
	cargo.unit_mass_kg = 9.0
	assert_true(PackagePackingRules.accepts(shell, cargo, 1), "1 kg shell plus 9 kg cargo fits")
	cargo.unit_mass_kg = 9.001
	assert_false(PackagePackingRules.accepts(shell, cargo, 1))


## A liquid and a solid of equal envelope/mass use the same capacity, keeping phase/hazards intact.
func test_capacity_does_not_infer_phase_or_hazards_from_shell() -> void:
	var solid: DEF_ItemCargo = _cargo(Vector3(0.1, 0.1, 0.1), 1.0)
	var liquid: DEF_ItemCargo = _cargo(solid.unit_size_m, solid.unit_mass_kg)
	liquid.phase = DEF_ItemCargo.Phase.LIQUID
	liquid.hazards = DEF_ItemCargo.Hazard.TOXIC | DEF_ItemCargo.Hazard.FLAMMABLE
	liquid.fragile = true
	var profiles: Array[DEF_PackagePacking] = [_large(), _small()]
	assert_same(
		PackagePackingRules.choose(profiles, solid, 1),
		PackagePackingRules.choose(profiles, liquid, 1),
	)
	assert_eq(solid.phase, DEF_ItemCargo.Phase.SOLID)
	assert_eq(solid.hazards, DEF_ItemCargo.Hazard.NONE)
	assert_eq(liquid.phase, DEF_ItemCargo.Phase.LIQUID)
	assert_eq(liquid.hazards, DEF_ItemCargo.Hazard.TOXIC | DEF_ItemCargo.Hazard.FLAMMABLE)
	assert_true(liquid.fragile)
#endregion


#region Canonical choices and malformed inputs
## Reordering candidates and a global RNG change cannot change an equal-capacity tie decision.
func test_equal_capacity_uses_unique_key_and_preserves_global_random_state() -> void:
	var first: DEF_PackagePacking = _small()
	first.key = &"first"
	var second: DEF_PackagePacking = _small()
	second.key = &"second"
	var cargo: DEF_ItemCargo = _cargo(Vector3(0.1, 0.1, 0.1), 1.0)
	var profiles: Array[DEF_PackagePacking] = [second, first]
	seed(507)
	var expected: int = randi()
	seed(507)
	assert_same(PackagePackingRules.choose(profiles, cargo, 1), first)
	profiles.reverse()
	assert_same(PackagePackingRules.choose(profiles, cargo, 1), first)
	assert_eq(randi(), expected)
	second.key = first.key
	assert_null(PackagePackingRules.choose(profiles, cargo, 1), "Ambiguous keys cannot select")


## Invalid count/data cannot wrap, overflow or pass a positive capacity comparison.
func test_invalid_cargo_and_quantities_reject() -> void:
	var shell: DEF_PackagePacking = _small()
	var cargo: DEF_ItemCargo = _cargo(Vector3(0.1, 0.1, 0.1), 1.0)
	assert_false(PackagePackingRules.valid_cargo(null))
	for quantity: int in [-1, 0, 100]:
		assert_false(PackagePackingRules.accepts(shell, cargo, quantity))
	for mass: float in [0.0, -1.0, INF, NAN]:
		cargo.unit_mass_kg = mass
		assert_false(PackagePackingRules.valid_cargo(cargo))
	cargo.unit_mass_kg = 1.0
	for size_m: Vector3 in [Vector3.ZERO, Vector3(-1, 1, 1), Vector3(INF, 1, 1)]:
		cargo.unit_size_m = size_m
		assert_false(PackagePackingRules.valid_cargo(cargo))
	cargo.unit_size_m = Vector3.ONE
	cargo.hazards = 8
	assert_false(PackagePackingRules.valid_cargo(cargo))
	cargo.hazards = DEF_ItemCargo.Hazard.NONE
	cargo.maximum_shipment_quantity = 0
	assert_false(PackagePackingRules.valid_cargo(cargo))
	cargo.maximum_shipment_quantity = 100
	assert_false(PackagePackingRules.valid_cargo(cargo))
	cargo.maximum_shipment_quantity = 1
	cargo.unit_size_m = Vector3(0.1, 0.1, 0.1)
	assert_true(PackagePackingRules.accepts(shell, cargo, 1))
	assert_false(PackagePackingRules.accepts(shell, cargo, 2), "Cargo's own unit limit is binding")


## Malformed tuning, duplicate scene paths and excessive catalogs fail without materialization.
func test_invalid_profiles_and_bounded_catalog_reject() -> void:
	assert_false(PackagePackingRules.valid_profile(null))
	var shell: DEF_PackagePacking = _small()
	shell.scene_variants.append(PACKAGE_SCENE)
	assert_false(PackagePackingRules.valid_profile(shell))
	shell.scene_variants = ["user://untrusted.tscn"]
	assert_false(PackagePackingRules.valid_profile(shell))
	shell.scene_variants = [PACKAGE_SCENE]
	for ratio: float in [0.0, 1.1, NAN]:
		shell.usable_volume_ratio = ratio
		assert_false(PackagePackingRules.valid_profile(shell))
	shell.usable_volume_ratio = 0.7
	shell.minimum_small_quantity = 5
	assert_false(PackagePackingRules.valid_profile(shell))
	shell.minimum_small_quantity = 1
	shell.maximum_gross_mass_kg = shell.empty_mass_kg
	assert_false(PackagePackingRules.valid_profile(shell))
	var profiles: Array[DEF_PackagePacking] = []
	profiles.resize(PackagePackingRules.MAX_PROFILES + 1)
	assert_null(PackagePackingRules.choose(profiles, _cargo(Vector3.ONE, 1.0), 1))
	assert_null(PackagePackingRules.choose([], _cargo(Vector3.ONE, 1.0), 1))
#endregion


#region Explicit authored-data fixtures
func _cargo(size_m: Vector3, mass_kg: float) -> DEF_ItemCargo:
	var cargo: DEF_ItemCargo = DEF_ItemCargo.new()
	cargo.maximum_shipment_quantity = PackagePackingRules.MAX_QUANTITY
	cargo.unit_size_m = size_m
	cargo.unit_mass_kg = mass_kg
	return cargo


func _small() -> DEF_PackagePacking:
	var shell: DEF_PackagePacking = DEF_PackagePacking.new()
	shell.key = &"small"
	shell.scene_variants = [PACKAGE_SCENE]
	shell.inner_size_m = Vector3(0.5, 0.3, 0.4)
	shell.usable_volume_ratio = 0.7
	shell.maximum_quantity = 4
	shell.maximum_gross_mass_kg = 10.0
	return shell


func _large() -> DEF_PackagePacking:
	var shell: DEF_PackagePacking = DEF_PackagePacking.new()
	shell.key = &"large"
	shell.scene_variants = [LARGE_SCENE]
	shell.inner_size_m = Vector3(1.0, 0.5, 0.8)
	shell.maximum_quantity = 32
	shell.minimum_small_quantity = 8
	shell.single_item_minimum_length_m = 0.6
	shell.empty_mass_kg = 2.0
	return shell
#endregion
