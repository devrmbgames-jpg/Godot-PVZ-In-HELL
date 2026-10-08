extends Observer
## Customer owner reserves committed physical contents for the still-matching inspection binding.
class_name O_CustomerInspectionCargo

#region Committed content consumption
## Reads package placement facts; Packages never call the higher inspection mutation owner.
func query() -> QueryBuilder:
	return q.on_event(PackageContentPlaced.EVENT)


## Rejects removed/rebound source reservations and removed/recycled content endpoints.
func each(_event: Variant, source: Entity, payload: Variant = null) -> void:
	var fact: PackageContentPlaced = payload as PackageContentPlaced
	assert(fact != null)
	var item: Entity = fact.item_reference.get_ref() as Entity
	if not EntityAvailability.contains(source, _world) or not EntityAvailability.contains(item, _world) or item.id != fact.item_id:
		return

	for binding: Relationship in fact.source_bindings:
		if binding.relation is R_InspectionCargo and binding in source.relationships:
			if EntityAvailability.contains(binding.target, _world):
				CustomerInspectionService.bind_contents(source, [item])
			return
#endregion
