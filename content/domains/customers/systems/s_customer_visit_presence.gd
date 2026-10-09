extends System
## Finalizes a started visit whose physical appearance has disappeared from the World.
class_name S_CustomerVisitPresence

#region Scheduling
## Presence reconciliation precedes arrival selection for the next available visit.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_CustomerFlow], Runs.Before: [S_CustomerCleanup]}


## Selects the authoritative visit aggregate and its current calendar.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerFlow, C_DayCycle])


## Reconciles only started, unfinished records; finish retains its one-shot commit guard.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for session: Entity in entities:
		var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
		var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		for visit: CustomerVisit in flow.visits:
			if visit.started and not visit.finished and CustomerFlowQueries.customer_for(visit.visit_id) == null:
				CustomerVisitLifecycle.finish(visit, cycle.day_index)
#endregion
