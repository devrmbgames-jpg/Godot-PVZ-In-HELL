extends System
## Owns Night preparation, quiescence, immutable capture and timed storage retries.
class_name S_NightSave

const MIN_RETRY_SECONDS: float = 0.1

#region Scheduled Night ownership
## Runs after calendar, payments, customer outcomes and quest outcomes.
func deps() -> Dictionary[int, Array]:
	return {Runs.After: [S_DayPhase, S_WalletDay, S_CustomerFlow, S_RefusalQuest]}


## Selects sessions with authoritative calendar and transient save workflow.
func query() -> QueryBuilder:
	return q.with_all([C_DayCycle, C_Autosave]).iterate([C_DayCycle, C_Autosave])


## Advances retry time and queues one step for the exact calendar/component context.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var cycles: Array = components[0]
	var states: Array = components[1]
	for index: int in entities.size():
		var cycle: C_DayCycle = cycles[index] as C_DayCycle
		var state: C_Autosave = states[index] as C_Autosave
		if cycle.phase != C_DayCycle.Phase.NIGHT:
			continue
		cycle.night_ready = state.last_saved_morning == cycle.day_index + 1
		if cycle.night_ready or state.work_queued:
			continue
		state.retry_remaining = maxf(0.0, state.retry_remaining - delta)
		if state.retry_remaining > 0.0:
			continue
		state.work_queued = true
		cmd.add_custom(_advance.bind(weakref(entities[index]), cycle, state,
			cycle.day_index, state.revision))
#endregion

#region Captured preparation and storage boundaries
func _advance(reference: WeakRef, cycle: C_DayCycle, state: C_Autosave,
		night_day: int, revision: int) -> void:
	var session: Entity = reference.get_ref() as Entity
	if session == null:
		return
	if session.get_component(C_DayCycle) != cycle or session.get_component(C_Autosave) != state:
		return
	if state.revision != revision:
		return
	state.work_queued = false
	if not EntityAvailability.contains(session, _world):
		return
	if cycle.day_index != night_day or cycle.phase != C_DayCycle.Phase.NIGHT:
		return
	if not state.rejected_path.is_empty() and state.path == state.rejected_path:
		_retry(state, ERR_UNAUTHORIZED)
		return

	if state.started_night != night_day:
		if not NpcHomeDeliveryService.finish_evening(night_day):
			_retry(state, ERR_INVALID_DATA)
			return
		state.started_night = night_day
		state.preparation = null
		state.prepared_snapshot = {}
		NightResetService.reset()

	if state.preparation == null:
		state.preparation = DistrictPopulationService.prepare_morning(night_day + 1)
	if not NightSaveService.drain_pending(_world):
		_retry(state, ERR_BUSY)
		return
	if not state.preparation.completed or not state.preparation.succeeded:
		_retry(state, ERR_BUSY if not state.preparation.completed else ERR_INVALID_DATA)
		return

	# Capture once after structural/outcome work drains. I/O retries read only this
	# detached value graph, even if unrelated live state changes meanwhile.
	if state.prepared_snapshot.is_empty():
		var root: Node = _world.get_parent()
		var snapshot: Dictionary = WorldSnapshotService.capture(root, night_day + 1)
		if not WorldSnapshotService.can_restore(snapshot, root):
			_retry(state, ERR_INVALID_DATA)
			return
		state.prepared_snapshot = snapshot.duplicate(true)
	var error: Error = AutosaveStore.write(state.prepared_snapshot, state.path)
	state.last_error = error
	if error != OK:
		_retry(state, error)
		return
	state.last_saved_morning = night_day + 1
	cycle.night_ready = true


func _retry(state: C_Autosave, error: Error) -> void:
	state.last_error = error
	state.retry_remaining = maxf(MIN_RETRY_SECONDS, state.retry_seconds)
#endregion
