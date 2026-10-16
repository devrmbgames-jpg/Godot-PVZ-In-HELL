extends GutTest
## Authored cargo facts agree with native item effects and support their committed quantity cap.

const ITEMS_ROOT: String = "res://content/domains/inventory/definitions/"
const SUPPLY: DEF_Delivery = preload(
	"res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
)
const PROFILES: Array[DEF_PackagePacking] = [
	preload("res://content/domains/packages/definitions/def_packing_small_a.tres"),
	preload("res://content/domains/packages/definitions/def_packing_small_b.tres"),
	preload("res://content/domains/packages/definitions/def_packing_medium.tres"),
	preload("res://content/domains/packages/definitions/def_packing_large.tres"),
	preload("res://content/domains/packages/definitions/def_packing_barrel.tres"),
	preload("res://content/domains/packages/definitions/def_packing_long.tres"),
]


#region Native immutable cargo definitions
## The isolated clothing room uses a physical order whose authored envelope matches the real body.
func test_room_clothing_has_physical_cargo_and_compatible_unit_and_bulk_packing() -> void:
	var item: DEF_InventoryItem = _item("work_clothes")
	assert_true(PackageOrderRules.is_orderable(item))
	var cargo: DEF_ItemCargo = item.cargo_profile
	assert_not_null(cargo)
	assert_eq(cargo.phase, DEF_ItemCargo.Phase.SOLID)
	assert_eq(cargo.hazards, DEF_ItemCargo.Hazard.NONE)
	var body: RigidBody3D = autofree(
		(load(item.world_pickup_scene) as PackedScene).instantiate()
	) as RigidBody3D
	var solver: ItemPlacementSolver = ItemPlacementSolver.new()
	assert_true(solver.prepare(body))
	assert_eq(solver.bounds_at(Transform3D.IDENTITY).size, cargo.unit_size_m)
	assert_eq(body.mass, cargo.unit_mass_kg)
	assert_not_null(PackagePackingRules.choose(PROFILES, cargo, 1))
	assert_not_null(PackagePackingRules.choose(PROFILES, cargo, cargo.maximum_shipment_quantity))


## Profiles carry independent identities and the actual native rupture scene, without new effects.
func test_catalog_profiles_preserve_native_hazard_ownership_and_fit_their_quantity_cap() -> void:
	var paths: Dictionary[String, bool] = { }
	var uids: Dictionary[int, bool] = { }
	for item: DEF_InventoryItem in SUPPLY.order_catalog:
		var cargo: DEF_ItemCargo = item.cargo_profile
		assert_not_null(cargo, String(item.key))
		assert_true(PackagePackingRules.valid_cargo(cargo))
		assert_false(paths.has(cargo.resource_path))
		paths[cargo.resource_path] = true
		var uid: int = ResourceLoader.get_resource_uid(cargo.resource_path)
		assert_ne(uid, -1)
		assert_false(uids.has(uid))
		uids[uid] = true
		assert_not_null(
			PackagePackingRules.choose(PROFILES, cargo, cargo.maximum_shipment_quantity)
		)
		var scene: PackedScene = load(item.world_pickup_scene) as PackedScene
		var body: E_GrabbableBody = autofree(scene.instantiate()) as E_GrabbableBody
		var native_hazard: PackedScene = null
		for component: Component in body.component_resources:
			if component is C_HazardEmitter:
				native_hazard = (component as C_HazardEmitter).hazard_scene
		assert_same(cargo.rupture_hazard, native_hazard, String(item.key))


## Shopping categories never replace the authored material phase or real hazard facts.
func test_artifact_is_solid_while_acid_and_blood_keep_distinct_liquid_facts() -> void:
	var artifact: DEF_InventoryItem = _item("holy_artifact")
	var acid: DEF_InventoryItem = _item("acid_barrel")
	var blood: DEF_InventoryItem = _item("blood_barrel")
	assert_eq(artifact.cargo_profile.phase, DEF_ItemCargo.Phase.SOLID)
	assert_eq(artifact.cargo_profile.hazards, DEF_ItemCargo.Hazard.NONE)
	assert_null(artifact.cargo_profile.rupture_hazard)
	assert_eq(acid.cargo_profile.phase, DEF_ItemCargo.Phase.LIQUID)
	assert_eq(acid.cargo_profile.hazards, DEF_ItemCargo.Hazard.TOXIC)
	assert_eq(blood.cargo_profile.phase, DEF_ItemCargo.Phase.LIQUID)
	assert_eq(blood.cargo_profile.hazards, DEF_ItemCargo.Hazard.NONE)
	assert_ne(acid.cargo_profile.rupture_hazard, blood.cargo_profile.rupture_hazard)
#endregion


#region Catalog fixture lookup
func _item(key: String) -> DEF_InventoryItem:
	var path: String = ITEMS_ROOT + "def_item_" + key + ".tres"
	return load(path) as DEF_InventoryItem
#endregion
