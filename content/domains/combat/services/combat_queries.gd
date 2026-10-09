extends RefCounted
## Читает живую цель боя из авторитетного R_CombatTarget без combat commands.
class_name CombatQueries

#region Operations
## Читает живого противника из R_CombatTarget.
static func target_for(actor: Entity) -> Entity:
	if not is_instance_valid(actor):
		return null

	for relation: Relationship in actor.relationships:
		if relation.relation is R_CombatTarget:
			return relation.target as Entity if is_instance_valid(relation.target) else null
	return null
#endregion
