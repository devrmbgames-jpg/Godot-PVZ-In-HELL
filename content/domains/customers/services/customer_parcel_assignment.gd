extends RefCounted
## Owns the live visit-to-parcel reservation; R_AssignedTo remains authoritative.
class_name CustomerParcelAssignment

#region Live parcel assignment
## Резервирует нужную коробку через R_AssignedTo, не меняя её физического положения.
static func bind_parcel(customer: Entity, visit: CustomerVisit) -> void:
	var parcel: Entity = PackageQueries.find_live_package(visit.package_id)
	if parcel == null:
		return

	var identity: C_Package = parcel.get_component(C_Package) as C_Package
	if identity != null and visit.package_history_id.is_empty():
		visit.package_history_id = identity.history_id
	var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
	if state == null or state.registration >= C_PackageState.Registration.DELIVERED:
		return

	for relation: Relationship in parcel.relationships:
		if relation.relation is R_AssignedTo:
			return

	var assignment: R_AssignedTo = R_AssignedTo.new()
	assignment.visit_id = visit.visit_id
	parcel.add_relationship(Relationship.new(assignment, customer))
#endregion
