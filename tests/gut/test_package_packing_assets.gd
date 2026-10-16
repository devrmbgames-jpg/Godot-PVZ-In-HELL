extends GutTest
## Native shell/profile agreement and real catalog envelopes, without spawning gameplay actors.

const PROFILES: Array[DEF_PackagePacking] = [
	preload("res://content/domains/packages/definitions/def_packing_small_a.tres"),
	preload("res://content/domains/packages/definitions/def_packing_small_b.tres"),
	preload("res://content/domains/packages/definitions/def_packing_medium.tres"),
	preload("res://content/domains/packages/definitions/def_packing_large.tres"),
	preload("res://content/domains/packages/definitions/def_packing_barrel.tres"),
	preload("res://content/domains/packages/definitions/def_packing_long.tres"),
]
const SUPPLY: DEF_Delivery = preload(
	"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
)


#region Native authored capacity
## Every declared interior remains inside its real collision envelope and has a unique identity.
func test_authored_profiles_fit_native_shell_envelopes() -> void:
	var keys: Dictionary[StringName, bool] = { }
	var scene_uids: Dictionary[int, bool] = { }
	for profile: DEF_PackagePacking in PROFILES:
		assert_true(PackagePackingRules.valid_profile(profile), String(profile.key))
		assert_false(keys.has(profile.key))
		keys[profile.key] = true
		for path: String in profile.scene_variants:
			var scene: PackedScene = load(path) as PackedScene
			var parcel: E_Package = autofree(scene.instantiate()) as E_Package
			assert_not_null(parcel, path)
			var uid: int = ResourceLoader.get_resource_uid(path)
			assert_ne(uid, -1)
			assert_false(scene_uids.has(uid), "Native scene identities remain distinct")
			scene_uids[uid] = true
			var solver: ItemPlacementSolver = ItemPlacementSolver.new()
			assert_true(solver.prepare(parcel as Node as RigidBody3D))
			var outer: Vector3 = solver.bounds_at(Transform3D.IDENTITY).size
			assert_lt(profile.inner_size_m.x, outer.x)
			assert_lt(profile.inner_size_m.y, outer.y)
			assert_lt(profile.inner_size_m.z, outer.z)
			assert_not_null(parcel.get_node_or_null("Box_C"))
			assert_not_null(parcel.get_node_or_null("Marks"))
			assert_not_null(parcel.get_node_or_null("Condition"))


## Actual native items, including the barrel and scythe, each have a physically adequate shell.
func test_every_catalog_unit_has_a_compatible_native_shell() -> void:
	for item: DEF_InventoryItem in SUPPLY.order_catalog:
		var cargo: DEF_ItemCargo = _measure_cargo(item)
		var selected: DEF_PackagePacking = PackagePackingRules.choose(PROFILES, cargo, 1)
		assert_not_null(selected, String(item.key))
		if item.key == &"acid_barrel":
			assert_eq(selected.key, &"barrel")
		if item.key == &"scythe":
			assert_eq(selected.key, &"long")


## Large packaging needs actual bulk; an individual toy uses a smaller physical shell.
func test_real_toy_envelope_uses_small_or_actual_bulk_profile() -> void:
	var toy: DEF_InventoryItem = load(
		"res://content/domains/inventory/definitions/def_item_toy_block.tres"
	) as DEF_InventoryItem
	var cargo: DEF_ItemCargo = _measure_cargo(toy)
	var single: DEF_PackagePacking = PackagePackingRules.choose(PROFILES, cargo, 1)
	var bulk: DEF_PackagePacking = PackagePackingRules.choose(PROFILES, cargo, 8)
	assert_not_null(single)
	assert_not_null(bulk)
	assert_eq(single.key, &"small_b")
	assert_eq(bulk.key, &"large")
	assert_false(PackagePackingRules.accepts(bulk, cargo, 1))
	assert_true(PackagePackingRules.accepts(bulk, cargo, 8))


## New variants retain the production package compiler rather than replacing it with scene glue.
func test_new_native_variants_compile_existing_package_capabilities() -> void:
	for path: String in [
		"res://content/domains/packages/entities/package_barrel.tscn",
		"res://content/domains/packages/entities/package_long.tscn",
	]:
		var scene: PackedScene = load(path) as PackedScene
		var parcel: E_Package = autofree(scene.instantiate()) as E_Package
		var context: EntitySpawnContext = EntityCompositionService.context_for(
			parcel,
			null,
			"fixture/packing/" + path.get_file(),
		)
		var plan: EntityBuildPlan = EntityCompositionService.build_plan(context)
		assert_true(plan.valid(), path)
		assert_true(parcel.components.is_empty(), "Preview never installs a live Component")
		assert_eq(parcel.package_id, "", "Preview never allocates a shipment ID")
#endregion


#region Physical fixture inputs
func _measure_cargo(item: DEF_InventoryItem) -> DEF_ItemCargo:
	var scene: PackedScene = load(item.world_pickup_scene) as PackedScene
	var body: RigidBody3D = autofree(scene.instantiate()) as RigidBody3D
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	assert_true(solver.prepare(body), String(item.key))
	var cargo: DEF_ItemCargo = DEF_ItemCargo.new()
	cargo.unit_mass_kg = body.mass
	cargo.unit_size_m = solver.bounds_at(Transform3D(body.transform.basis, Vector3.ZERO)).size
	return cargo
#endregion
