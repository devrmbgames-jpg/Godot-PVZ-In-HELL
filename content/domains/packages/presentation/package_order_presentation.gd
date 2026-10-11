extends RefCounted
## Reads immutable arrival projections so terminal rows, search and archives agree after departure.
class_name PackageOrderPresentation


#region Arrival record views
## Shows committed contents and quantity, falling back to authored descriptions for legacy parcels.
static func title(record: PackageRegistrationRecord) -> String:
	if record.ordered_item != null:
		var quantity: int = record.definition.content_quantity
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


## Fragile/heavy describe the shell; the old liquid payload is replaced by the committed item.
static func tags(record: PackageRegistrationRecord) -> int:
	if record.definition == null:
		return 0
	return (
		record.definition.tags & ~DEF_Package.Tag.LIQUID
		if record.ordered_item != null
		else record.definition.tags
	)
#endregion
