extends RefCounted
## Reads immutable arrival projections so terminal rows, search and archives agree after departure.
class_name PackageOrderPresentation


#region Arrival record views
## Shows committed contents and quantity, falling back to authored descriptions for legacy parcels.
static func title(record: PackageRegistrationRecord) -> String:
	if record.ordered_item != null:
		var quantity: int = record.ordered_quantity
		return (
			record.ordered_item.display_name + " ×%d" % quantity
			if quantity > 1
			else record.ordered_item.display_name
		)
	if record.definition != null and not record.definition.description.is_empty():
		return record.definition.description
	return record.package_id


## Content-specific legacy warnings do not describe a different catalog payload.
static func comment(record: PackageRegistrationRecord) -> String:
	return (
		record.definition.comment
		if record.ordered_item == null and record.definition != null
		else ""
	)


## Handling facts use the immutable arrival composition, including after the live body leaves.
static func tags(record: PackageRegistrationRecord) -> int:
	if record.definition == null:
		return 0
	return PackageCargoRules.tags(
		record.definition, record.ordered_item, record.ordered_quantity, record.packing_profile,
	)


## Full arrival mass in kilograms; opening a live box never changes archive weight or sorting.
static func mass_kg(record: PackageRegistrationRecord) -> float:
	if record.definition == null:
		return 0.0
	return PackageCargoRules.full_mass_kg(
		record.definition, record.ordered_item, record.ordered_quantity, record.packing_profile,
	)


static func hazard_class(record: PackageRegistrationRecord) -> int:
	return (
		PackageCargoRules.hazard_class(record.definition, record.ordered_item)
		if record.definition != null else DEF_Package.HazardClass.NORMAL
	)


static func is_explosive(record: PackageRegistrationRecord) -> bool:
	return record.definition != null and PackageCargoRules.is_explosive(
		record.definition, record.ordered_item,
	)


static func is_toxic(record: PackageRegistrationRecord) -> bool:
	return record.definition != null and PackageCargoRules.is_toxic(
		record.definition, record.ordered_item,
	)


static func is_flammable(record: PackageRegistrationRecord) -> bool:
	return record.definition != null and PackageCargoRules.is_flammable(
		record.definition, record.ordered_item,
	)


static func has_unclassified_hazard(record: PackageRegistrationRecord) -> bool:
	return record.definition != null and PackageCargoRules.has_unclassified_hazard(
		record.definition, record.ordered_item,
	)
#endregion
