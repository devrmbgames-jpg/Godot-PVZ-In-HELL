extends RefCounted
## Reads native terminal panels through their synchronous owner boundary.
class_name TerminalQueries


#region Actual terminal reader
## Queries only physical interaction targets; unrelated modal panels do not count.
static func reading(player: Entity) -> bool:
	var targets: QueryBuilder = ECS.world.query.with_all([C_Interactable, C_InteractionActionSet])
	for target: Entity in targets.enabled().execute():
		if target is E_Terminal and (target as E_Terminal).is_open_for(player):
			return true
	return false
#endregion
