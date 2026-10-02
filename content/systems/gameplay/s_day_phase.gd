extends System
## Processes queued day transitions; query/command callers use DayPhaseService.
class_name S_DayPhase

signal night_started(day_index: int)
signal morning_started(day_index: int)
signal phase_changed(day_index: int, phase: C_DayCycle.Phase)


func query() -> QueryBuilder:
	return q.with_all([C_DayCycle]).iterate([C_DayCycle])


func process(_entities: Array[Entity], components: Array, delta: float) -> void:
	var cycles: Array = components[0]
	for index: int in cycles.size():
		var cycle: C_DayCycle = cycles[index] as C_DayCycle
		if cycle.phase == C_DayCycle.Phase.DAY and is_finite(delta) and delta >= 0.0:
			cycle.shift_elapsed_seconds += delta
		elif cycle.phase == C_DayCycle.Phase.MORNING:
			cycle.shift_elapsed_seconds = 0.0
		if cycle.phase == C_DayCycle.Phase.NIGHT:
			if cycle.night_ready:
				cycle.day_index += 1
				cycle.phase = C_DayCycle.Phase.MORNING
				cycle.pending_transition = null
				morning_started.emit(cycle.day_index)
				phase_changed.emit(cycle.day_index, cycle.phase)
			continue

		var request: DayTransitionRequest = cycle.pending_transition
		cycle.pending_transition = null
		if request == null or request.expected_day != cycle.day_index:
			continue
		if (
			request.expected_phase != cycle.phase
			or not DayPhaseService.permits(cycle, request.kind)
		):
			continue
		match request.kind:
			DayTransitionRequest.Kind.START_SHIFT:
				cycle.shift_elapsed_seconds = 0.0
				cycle.phase = C_DayCycle.Phase.DAY
			DayTransitionRequest.Kind.FINISH_SHIFT:
				cycle.phase = C_DayCycle.Phase.EVENING
			DayTransitionRequest.Kind.SLEEP:
				cycle.phase = C_DayCycle.Phase.NIGHT
				cycle.night_ready = not _entities[index].has_component(C_Autosave)
				night_started.emit(cycle.day_index)
		phase_changed.emit(cycle.day_index, cycle.phase)
