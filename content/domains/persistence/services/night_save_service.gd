extends RefCounted
## Startup slot policy and restore status; scheduled Night capture/retries belong to S_NightSave.
class_name NightSaveService


#region Восстановление при запуске
## Восстанавливает совместимый слот или сообщает причину отказа без удаления файла.
## false также означает отсутствие слота.
## При construction_failed уровень должен покинуть незавершённый World.
## Успех использует deferred reconciliation: level ещё обязан завершить global startup.
static func restore_startup(root: Node, state: C_Autosave) -> bool:
	var snapshot: Dictionary = AutosaveStore.read(state.path)
	if snapshot.is_empty():
		if FileAccess.file_exists(state.path):
			state.rejected_path = state.path
		state.startup_status = (
			"Сохранение повреждено — новое прохождение"
			if FileAccess.file_exists(state.path)
			else "Новое прохождение"
		)
		return false
	if snapshot.get("version") != AutosaveStore.SCHEMA_VERSION:
		state.rejected_path = state.path
		state.startup_status = (
			"Старое сохранение несовместимо с живым районом. "
			+ "Файл сохранён; начните новое прохождение."
		)
		return false
	if not WorldSnapshotService.can_restore(snapshot, root):
		state.rejected_path = state.path
		state.startup_status = "Сохранение несовместимо — новое прохождение"
		return false
	if not WorldSnapshotService.restore(snapshot, root, true):
		state.construction_failed = true
		state.rejected_path = state.path
		state.startup_status = "Сохранение несовместимо — новое прохождение"
		return false

	state.last_saved_morning = int(snapshot.morning_day)
	state.startup_status = "Восстановлено утро %d" % state.last_saved_morning
	return true
#endregion
