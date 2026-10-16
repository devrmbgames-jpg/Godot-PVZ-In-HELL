extends Observer
## Records discrete release of stolen cargo; common grab lifecycle owns physical cleanup.
class_name O_CustomerParcelIncidents


func query() -> QueryBuilder:
	return q.on_relationship_removed([R_HeldBy])


func each(_event: Variant, parcel: Entity, payload: Variant = null) -> void:
	var binding: Relationship = payload as Relationship
	if binding != null:
		CustomerParcelIncidentService.grip_removed(parcel, binding)
