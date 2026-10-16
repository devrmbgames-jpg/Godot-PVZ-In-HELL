extends RefCounted
## Pure physical facts shared by live parcel views and immutable arrival composition projections.
class_name PackageCargoRules


#region Actual payload and handling facts
## Full arrival mass in kilograms; consumed live bodies do not change the archive's shipment facts.
static func full_mass_kg(
	definition: DEF_Package,
	item: DEF_InventoryItem,
	quantity: int,
	packing: DEF_PackagePacking,
) -> float:
	if item == null:
		return definition.mass_kg
	return PackagePackingRules.gross_mass_kg(packing, item.cargo_profile, quantity)


## Phase/fragility describe actual cargo; heavy is an authored warning about combined physical mass.
static func tags(
	definition: DEF_Package,
	item: DEF_InventoryItem,
	quantity: int,
	packing: DEF_PackagePacking,
) -> int:
	if item == null:
		return definition.tags
	var result: int = 0
	if item.cargo_profile.fragile:
		result |= DEF_Package.Tag.FRAGILE
	if item.cargo_profile.phase == DEF_ItemCargo.Phase.LIQUID:
		result |= DEF_Package.Tag.LIQUID
	if full_mass_kg(definition, item, quantity, packing) > packing.heavy_mark_mass_kg:
		result |= DEF_Package.Tag.HEAVY
	return DEF_Package.Tag.NORMAL if result == 0 else result


## The diagnostic ID has one class; independent hazard icons retain every actual cargo flag.
## Priority is explosive, toxic, flammable/other, liquid, fragile, then ordinary solid cargo.
static func hazard_class(definition: DEF_Package, item: DEF_InventoryItem) -> int:
	if item == null:
		return definition.history_hazard_class
	if is_explosive(definition, item):
		return DEF_Package.HazardClass.EXPLOSIVE
	if is_toxic(definition, item):
		return DEF_Package.HazardClass.TOXIC
	if is_flammable(definition, item):
		return DEF_Package.HazardClass.OTHER
	if item.cargo_profile.phase == DEF_ItemCargo.Phase.LIQUID:
		return DEF_Package.HazardClass.LIQUID
	if item.cargo_profile.fragile:
		return DEF_Package.HazardClass.FRAGILE
	return DEF_Package.HazardClass.NORMAL


static func is_explosive(definition: DEF_Package, item: DEF_InventoryItem) -> bool:
	return (
		bool(item.cargo_profile.hazards & DEF_ItemCargo.Hazard.EXPLOSIVE)
		if item != null
		else definition.history_hazard_class == DEF_Package.HazardClass.EXPLOSIVE
	)


static func is_toxic(definition: DEF_Package, item: DEF_InventoryItem) -> bool:
	return (
		bool(item.cargo_profile.hazards & DEF_ItemCargo.Hazard.TOXIC)
		if item != null
		else definition.history_hazard_class == DEF_Package.HazardClass.TOXIC
	)


static func is_flammable(_definition: DEF_Package, item: DEF_InventoryItem) -> bool:
	return item != null and bool(item.cargo_profile.hazards & DEF_ItemCargo.Hazard.FLAMMABLE)


## Retains an unclassified native rupture warning without inventing category/ID exception lists.
static func has_unclassified_hazard(definition: DEF_Package, item: DEF_InventoryItem) -> bool:
	if item != null:
		return (
			item.cargo_profile.rupture_hazard != null
			and item.cargo_profile.hazards == DEF_ItemCargo.Hazard.NONE
		)
	return (
		definition.history_hazard_class == DEF_Package.HazardClass.OTHER
		or definition.hazard_on_damaged != null or definition.hazard_on_destroyed != null
	)


## Read-only effect identity for debug presentation; emitting still requires the one-shot owner.
static func rupture_scene(
	definition: DEF_Package,
	item: DEF_InventoryItem,
	destroyed: bool,
) -> PackedScene:
	if item != null:
		return item.cargo_profile.rupture_hazard
	return definition.hazard_on_destroyed if destroyed else definition.hazard_on_damaged
#endregion
