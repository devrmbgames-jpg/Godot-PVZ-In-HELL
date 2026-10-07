extends System
## Bootstraps missed/restored district calendar state; explicit facts own actual lifecycle work.
class_name S_District

#region Bootstrap scheduling
## Reconciliation precedes customer arrivals, day transitions and native decisions/navigation.
func deps() -> Dictionary[int, Array]:
	return {Runs.Before: [S_CustomerFlow, S_DayPhase, S_NpcDecision, S_NpcIntent]}


## Selects the authoritative district/day aggregate and its derived reconciliation cache.
func query() -> QueryBuilder:
	return q.with_all([C_District, C_DayCycle])


## Publishes only a missing calendar snapshot, never a recurring population/service dispatcher.
func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	for session: Entity in entities:
		cmd.add_custom(_ensure_calendar.bind(session))


func _ensure_calendar(session: Entity) -> void:
	if not EntityAvailability.contains(session, _world):
		return
	var district: C_District = session.get_component(C_District) as C_District
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	if district.lifecycle_day != cycle.day_index or district.lifecycle_phase != int(cycle.phase):
		_world.emit_event(DayPhaseChanged.EVENT, session, DayPhaseChanged.from_cycle(cycle))
#endregion
