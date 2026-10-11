extends RefCounted
## Validates committed order payloads and their immutable arrival projections before live mutation.
class_name PackageOrderSnapshotRules


#region Committed order preflight
## Selected items require contents capability and must agree with existing ledger projections.
static func valid(components: Dictionary[String, Dictionary]) -> bool:
	var arrivals: Dictionary[String, PackageRegistrationRecord] = { }
	for key: String in components:
		var types: Dictionary = components[key]
		if not types.has(C_PackageLedger):
			continue
		var ledger: C_PackageLedger = types[C_PackageLedger] as C_PackageLedger
		for record: PackageRegistrationRecord in ledger.records:
			if record == null or arrivals.has(record.package_id):
				return false
			if record.ordered_item != null:
				if (
					record.definition == null or record.definition.unpack_scene == null
					or not PackageOrderRules.is_orderable(record.ordered_item)
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
		if contents.selected_item != null:
			if (
				package.definition.unpack_scene == null
				or not PackageOrderRules.is_orderable(contents.selected_item)
			):
				return false
		var arrival: PackageRegistrationRecord = arrivals.get(package.package_id)
		if arrival != null and arrival.ordered_item != contents.selected_item:
			return false
	return true
#endregion
