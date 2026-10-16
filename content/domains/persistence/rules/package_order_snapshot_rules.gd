extends RefCounted
## Validates committed order payloads and their immutable arrival projections before live mutation.
class_name PackageOrderSnapshotRules


#region Committed order preflight
## Selected items require contents capability and must agree with existing ledger projections.
## Reads already decoded snapshot Components; neither reconstructs parcels nor commits fulfillment.
static func valid(
	components: Dictionary[String, Dictionary], records: Dictionary[String, Dictionary],
) -> bool:
	var arrivals: Dictionary[String, PackageRegistrationRecord] = { }
	for key: String in components:
		var types: Dictionary = components[key]
		if not types.has(C_PackageLedger):
			continue
		var ledger: C_PackageLedger = types[C_PackageLedger] as C_PackageLedger
		for record: PackageRegistrationRecord in ledger.records:
			if record == null or arrivals.has(record.package_id):
				return false
			if not PackageShipmentRules.valid_contents(
				record.ordered_item, record.ordered_quantity, record.packing_profile,
			):
				return false
			if record.ordered_item != null:
				if (
					record.definition == null or record.definition.unpack_scene == null
					or not PackageOrderRules.is_orderable(record.ordered_item)
				):
					return false
				var history: PackageHistoryId = PackageHistoryId.parse(record.history_id)
				var full_mass: float = PackageCargoRules.full_mass_kg(
					record.definition, record.ordered_item, record.ordered_quantity,
					record.packing_profile,
				)
				if (
					history == null
					or history.mass_tenths_kg != roundi(full_mass * PackageHistoryId.MASS_SCALE)
					or history.hazard_class != PackageCargoRules.hazard_class(
						record.definition, record.ordered_item,
					)
				):
					return false
			arrivals[record.package_id] = record
	for key: String in components:
		var types: Dictionary = components[key]
		if not types.has(C_PackageContents):
			continue
		if not types.has(C_Package):
			return false
		var contents: C_PackageContents = types[C_PackageContents] as C_PackageContents
		var package: C_Package = types[C_Package] as C_Package
		if not PackageShipmentRules.valid(
			contents.selected_item, contents.quantity, contents.packing_profile,
			String(records[key].scene),
		):
			return false
		if contents.selected_item != null:
			if (
				package.definition.unpack_scene == null
				or not PackageOrderRules.is_orderable(contents.selected_item)
			):
				return false
		var arrival: PackageRegistrationRecord = arrivals.get(package.package_id)
		if arrival != null:
			if (
				arrival.ordered_item != contents.selected_item
				or arrival.ordered_quantity != contents.quantity
				or arrival.packing_profile != contents.packing_profile
				or arrival.definition != package.definition
			):
				return false
	return true
#endregion
