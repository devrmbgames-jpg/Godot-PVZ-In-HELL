extends RefCounted
## Reads inspection reservations from their authoritative Relationships, without executing inspection.
class_name CustomerInspectionQueries

#region Inspection reservation queries
## Возвращает живого владельца резерва R_InspectionCargo для предмета.
static func owner_for(item: Entity) -> E_NpcCharacter:
	if not EntityAvailability.contains(item, ECS.world):
		return null

	for binding: Relationship in item.relationships:
		if binding.relation is R_InspectionCargo and EntityAvailability.contains(binding.target as Entity, ECS.world):
			var customer: E_NpcCharacter = binding.target as E_NpcCharacter
			if customer != null and not customer.has_component(C_Death):
				return customer
	return null


## Возвращает снимок предметов, связанных с клиентом через R_InspectionCargo.
static func cargo(customer: Entity) -> Array[Entity]:
	if not is_instance_valid(ECS.world):
		return []
	return ECS.world.query.with_relationship([Relationship.new(R_InspectionCargo.new(), customer)]).execute().duplicate()


## Находит исходную коробку среди зарезервированного груза клиента.
static func parcel_for(customer: Entity) -> Entity:
	for item: Entity in cargo(customer):
		for binding: Relationship in item.relationships:
			if binding.relation is R_InspectionCargo and binding.target == customer and (binding.relation as R_InspectionCargo).original_parcel:
				return item
	return null


#endregion
