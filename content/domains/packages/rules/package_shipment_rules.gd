extends RefCounted
## Prepares bounded deterministic cargo/quantity/shell decisions without World or global RNG state.
class_name PackageShipmentRules


#region Quantity and shell decisions
## Selects uniformly among feasible quantities for an already chosen item, then packs that count.
## Unsupported gaps are excluded; this operation never substitutes a different catalog item.
static func choose(
	item: DEF_InventoryItem,
	profiles: Array[DEF_PackagePacking],
	world_seed: int,
	package_id: String,
	day_index: int,
) -> PackageShipmentPlan:
	if not _valid_inputs(item, profiles, package_id, day_index):
		return null
	var quantities: Array[int] = []
	var packings: Array[DEF_PackagePacking] = []
	for quantity: int in range(1, item.cargo_profile.maximum_shipment_quantity + 1):
		var packing: DEF_PackagePacking = PackagePackingRules.choose(
			profiles,
			item.cargo_profile,
			quantity,
		)
		if packing != null:
			quantities.append(quantity)
			packings.append(packing)
	if quantities.is_empty():
		return null

	var random: RandomNumberGenerator = DecisionRandomRules.generator(
		world_seed,
		package_id,
		day_index,
		"package/shipment_quantity",
	)
	var index: int = random.randi_range(0, quantities.size() - 1)
	return _plan(item, quantities[index], packings[index], world_seed, package_id, day_index)


## Packs an explicit count without clamping it or inventing units to justify a larger shell.
## Native scene compatibility is checked later by the existing materialization/compiler boundary.
static func for_quantity(
	item: DEF_InventoryItem,
	quantity: int,
	profiles: Array[DEF_PackagePacking],
	world_seed: int,
	package_id: String,
	day_index: int,
) -> PackageShipmentPlan:
	if not _valid_inputs(item, profiles, package_id, day_index):
		return null
	var packing: DEF_PackagePacking = PackagePackingRules.choose(
		profiles,
		item.cargo_profile,
		quantity,
	)
	if packing == null:
		return null
	return _plan(item, quantity, packing, world_seed, package_id, day_index)


static func _valid_inputs(
	item: DEF_InventoryItem,
	profiles: Array[DEF_PackagePacking],
	package_id: String,
	day_index: int,
) -> bool:
	return (
		not package_id.is_empty() and day_index >= 1
		and not profiles.is_empty() and profiles.size() <= PackagePackingRules.MAX_PROFILES
		and PackageOrderRules.is_orderable(item)
	)


static func _plan(
	item: DEF_InventoryItem,
	quantity: int,
	packing: DEF_PackagePacking,
	world_seed: int,
	package_id: String,
	day_index: int,
) -> PackageShipmentPlan:
	var paths: Array[String] = packing.scene_variants.duplicate()
	paths.sort()
	var random: RandomNumberGenerator = DecisionRandomRules.generator(
		world_seed,
		package_id,
		day_index,
		"package/shipment_scene",
	)
	var scene_path: String = paths[random.randi_range(0, paths.size() - 1)]
	return PackageShipmentPlan.new(item, quantity, packing, scene_path)
#endregion
