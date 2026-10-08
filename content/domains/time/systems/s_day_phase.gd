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


## Повторно проверяет запрос и переводит готовую ночь в следующее утро без elapsed time skip.
func process(_entities: Array[Entity], components: Array, _delta: float) -> void:
	var cycles: Array = components[0]
	for index: int in cycles.size():
		var cycle: C_DayCycle = cycles[index] as C_DayCycle
		if cycle.phase == C_DayCycle.Phase.MORNING:
			cycle.shift_start_tick = -1
			cycle.shift_end_tick = -1
		if cycle.phase == C_DayCycle.Phase.NIGHT:
			if cycle.night_ready:
				cycle.day_index += 1
				cycle.phase = C_DayCycle.Phase.MORNING
				cycle.pending_transition = null
				morning_started.emit(cycle.day_index)
				_publish_phase(_entities[index], cycle)
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
				cmd.add_custom(_commit_start_shift.bind(weakref(_entities[index]), cycle, request))
				continue
			DayTransitionRequest.Kind.FINISH_SHIFT:
				cycle.shift_end_tick = cycle.clock.elapsed_ticks
				cycle.phase = C_DayCycle.Phase.EVENING
			DayTransitionRequest.Kind.SLEEP:
				cycle.phase = C_DayCycle.Phase.NIGHT
				var preparation: NightPreparationRequirement = NightPreparationRequirement.new()
				_world.emit_event(NightPreparationRequirement.EVENT, _entities[index], preparation)
				cycle.night_ready = not preparation.is_required()
				night_started.emit(cycle.day_index)
		_publish_phase(_entities[index], cycle)

#endregion


#region Безопасная фиксация утренней команды
func _commit_start_shift(
	session_reference: WeakRef, cycle: C_DayCycle, request: DayTransitionRequest,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if not EntityAvailability.contains(session, _world) or session.get_component(C_DayCycle) != cycle:
		return
	if cycle.day_index != request.expected_day or cycle.phase != request.expected_phase:
		return
	if not DayPhaseService.permits(cycle, request.kind) or not ReceivingShiftService.commit_departure(cycle):
		return

	cycle.shift_start_tick = cycle.clock.elapsed_ticks
	cycle.shift_end_tick = -1
	cycle.phase = C_DayCycle.Phase.DAY
	_publish_phase(session, cycle)
#endregion

#region Committed phase notification
func _publish_phase(session: Entity, cycle: C_DayCycle) -> void:
	_world.emit_event(DayPhaseChanged.EVENT, session, DayPhaseChanged.from_cycle(cycle))
	phase_changed.emit(cycle.day_index, cycle.phase)
#endregion
