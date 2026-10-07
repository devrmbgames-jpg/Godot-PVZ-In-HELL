extends System
## Owns the arrival clock and history reconciliation; settlement migration follows in 13.
class_name S_CustomerFlow

#region Scheduling
## Arrivals commit before phase gates and navigation consume their state.
func deps() -> Dictionary[int, Array]:
	return {Runs.Before: [S_DayPhase, S_NpcIntent]}


## Selects the authoritative visit/day session.
func query() -> QueryBuilder:
	return q.with_all([C_CustomerFlow, C_DayCycle])


## Queues the complete arrival step at this System's concrete buffer boundary.
func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for session: Entity in entities:
		cmd.add_custom(_advance.bind(session, delta))


func _advance(session: Entity, delta: float) -> void:
	if not EntityAvailability.contains(session, _world):
		return
	var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle

	# Bootstrap/load and missed authored transitions reconcile once, never each frame.
	if flow.planning_day != cycle.day_index or flow.planning_phase != int(cycle.phase):
		_world.emit_event(DayPhaseChanged.EVENT, session, DayPhaseChanged.from_cycle(cycle))
		if flow.planning_day != cycle.day_index or flow.planning_phase != int(cycle.phase):
			return
	if cycle.phase == C_DayCycle.Phase.MORNING:
		flow.arrival_cooldown_seconds = 0.0
	elif is_finite(delta) and delta >= 0.0:
		flow.arrival_cooldown_seconds = maxf(0.0, flow.arrival_cooldown_seconds - delta)

	_sync_history(flow)
	CustomerFlowService.tick(flow, cycle)

#endregion

#region Derived package identity
func _sync_history(flow: C_CustomerFlow) -> void:
	for visit: CustomerVisit in flow.visits:
		if not visit.package_history_id.is_empty():
			continue
		var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
		if parcel != null:
			var identity: C_Package = parcel.get_component(C_Package) as C_Package
			visit.package_history_id = identity.history_id
#endregion
