extends RefCounted
## Однократно готовит утро района и повторяет запись без повторного завершения вечера и заселения.
class_name NightSaveService

const MIN_RETRY_SECONDS: float = 0.1


#region Ночная подготовка и запись
## Завершает обещания и размещение один раз на ночь; повторно снимает и записывает подготовленное утро.
static func process(session: Entity, cycle: C_DayCycle, state: C_Autosave, delta: float) -> void:
	if cycle.phase != C_DayCycle.Phase.NIGHT:
		return

	cycle.night_ready = false
	if state.last_saved_morning == cycle.day_index + 1:
		cycle.night_ready = true
		return
	if state.started_night != cycle.day_index:
		state.started_night = cycle.day_index
		NpcHomeDeliveryService.finish_evening(cycle.day_index)
		NightResetService.reset()
		DistrictPopulationService.prepare_morning(cycle.day_index + 1)
	state.retry_remaining = maxf(0.0, state.retry_remaining - delta)
	if state.retry_remaining > 0.0:
		return

	var root: Node = ECS.world.get_parent()
	var snapshot: Dictionary = WorldSnapshotService.capture(root, cycle.day_index + 1)
	if not WorldSnapshotService.valid(snapshot, root):
		state.last_error = ERR_INVALID_DATA
	else:
		state.last_error = AutosaveStore.write(snapshot, state.path)
	if state.last_error == OK:
		state.last_saved_morning = cycle.day_index + 1
		cycle.night_ready = true
	else:
		state.retry_remaining = maxf(MIN_RETRY_SECONDS, state.retry_seconds)
#endregion


#region Восстановление при запуске
## Восстанавливает совместимый слот или сообщает причину отказа без удаления файла.
static func restore_startup(root: Node, state: C_Autosave) -> bool:
	var snapshot: Dictionary = AutosaveStore.read(state.path)
	if snapshot.is_empty():
		state.startup_status = "Сохранение повреждено — новое прохождение" if FileAccess.file_exists(state.path) else "Новое прохождение"
		return false
	if snapshot.get("version") != AutosaveStore.SCHEMA_VERSION:
		state.startup_status = "Старое сохранение несовместимо с живым районом. Файл сохранён; начните новое прохождение."
		return false
	if not WorldSnapshotService.restore(snapshot, root):
		state.startup_status = "Сохранение несовместимо — новое прохождение"
		return false

	state.last_saved_morning = int(snapshot.morning_day)
	state.startup_status = "Восстановлено утро %d" % state.last_saved_morning
	return true
#endregion
