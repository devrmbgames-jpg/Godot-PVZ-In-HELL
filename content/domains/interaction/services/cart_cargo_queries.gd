extends RefCounted
## Читает авторитетное живое крепление груза к тележке без изменения крепления.
class_name CartCargoQueries

#region Operations
## Читает авторитетную связь R_CartCargo предмета.
static func relationship(cargo: Entity) -> Relationship:
	if not is_instance_valid(cargo):
		return null

	for candidate: Relationship in cargo.relationships:
		if candidate.relation is R_CartCargo:
			return candidate
	return null
#endregion
