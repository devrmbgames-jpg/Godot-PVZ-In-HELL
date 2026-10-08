extends System
## Dispatches the next appearance after terminal phase commits and projects remaining visits.
class_name S_CustomerArrivals

#region Scheduling
## Preserves phase completion before arrival selection and day/navigation consumers.
func deps() -> Dictionary[int, Array]:
	return {
		Runs.After: [S_CustomerFlow, S_CustomerVisitPresence, S_CustomerCleanup,
			S_CustomerApproach, S_CustomerWaiting, S_CustomerInspection, S_CustomerDeparture],
		Runs.Before: [S_DayPhase, S_NpcDecision, S_NpcIntent],
	}


## Selects the authoritative visit/day session, never an individual BT role.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerFlow, C_DayCycle])


## Queues selection after the current appearance's concrete commit boundary.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for session: Entity in entities:
		var captured_flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
		var captured_cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		cmd.add_custom(_dispatch.bind(weakref(session), captured_flow, captured_cycle))


func _dispatch(session_reference: WeakRef, captured_flow: C_CustomerFlow, captured_cycle: C_DayCycle) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if not EntityAvailability.contains(session, _world) \
			or session.get_component(C_CustomerFlow) != captured_flow \
			or session.get_component(C_DayCycle) != captured_cycle:
		return

	var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	if flow.planning_day != cycle.day_index or flow.planning_phase != int(cycle.phase):
		return
	cycle.remaining_customer_events = CustomerFlowService.actionable_remaining(flow, cycle.day_index)

	if DistrictPopulationService.current() != null:
		# District queue selection remains the bounded migration scope of task 16.
		NpcServiceRole.enqueue_next(flow, cycle)
	else:
		var visit: CustomerVisit = CustomerFlowService.next_arrival(flow, cycle)
		if visit != null:
			CustomerFlowService.start_visit(flow, visit, cycle.day_index)
#endregion
