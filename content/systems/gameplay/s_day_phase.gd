extends System
## Исполняет ожидающий переход с повторной проверкой; запросы проходят через DayPhaseService.
class_name S_DayPhase

## Сон принят и началась ночная подготовка указанного дня.
signal night_started(day_index: int)
## Ночная подготовка разрешила переход к следующему игровому дню.
signal morning_started(day_index: int)
## Уведомляет о принятом изменении дня/фазы после записи состояния.
signal phase_changed(day_index: int, phase: C_DayCycle.Phase)


#region Планирование переходов
## Выбирает сессионные данные игрового цикла.
func query() -> QueryBuilder:
	return q.with_all([C_DayCycle]).iterate([C_DayCycle])


## Считает время смены, повторно проверяет запрос и переводит готовую ночь в следующее утро.
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
				cmd.add_custom(_commit_start_shift.bind(cycle, request))
				continue
			DayTransitionRequest.Kind.FINISH_SHIFT:
				cycle.phase = C_DayCycle.Phase.EVENING
			DayTransitionRequest.Kind.SLEEP:
				cycle.phase = C_DayCycle.Phase.NIGHT
				cycle.night_ready = not _entities[index].has_component(C_Autosave)
				night_started.emit(cycle.day_index)
		phase_changed.emit(cycle.day_index, cycle.phase)

#endregion


#region Безопасная фиксация утренней команды
func _commit_start_shift(cycle: C_DayCycle, request: DayTransitionRequest) -> void:
	if cycle.day_index != request.expected_day or cycle.phase != request.expected_phase:
		return
	if not DayPhaseService.permits(cycle, request.kind) or not ReceivingShiftService.commit_departure(cycle):
		return

	cycle.shift_elapsed_seconds = 0.0
	cycle.phase = C_DayCycle.Phase.DAY
	phase_changed.emit(cycle.day_index, cycle.phase)
#endregion
