extends RefCounted
## Explicit save composition: command quiescence and validated startup restore.
class_name NightSaveService

#region Explicit quiescence barrier
## Drains structural/outcome commands without running a scheduled tick.
## A non-settling reaction chain rejects capture instead of saving partial state.
static func drain_pending(world: World) -> bool:
	const MAX_DRAIN_PASSES: int = 32
	for _pass_index: int in MAX_DRAIN_PASSES:
		var pending: bool = false
		for owner: System in world.systems:
			if owner.has_pending_commands():
				pending = true
				owner.cmd.execute()
		for owner: Observer in world.observers:
			if owner.has_pending_commands():
				pending = true
				owner.cmd.execute()
		if not pending:
			return true
	return false
#endregion


#region Восстановление при запуске
## Восстанавливает совместимый слот или сообщает причину отказа без удаления файла.
static func restore_startup(root: Node, state: C_Autosave) -> bool:
	var snapshot: Dictionary = AutosaveStore.read(state.path)
	if snapshot.is_empty():
		if FileAccess.file_exists(state.path):
			state.rejected_path = state.path
		state.startup_status = ("Сохранение повреждено — новое прохождение"
			if FileAccess.file_exists(state.path) else "Новое прохождение")
		return false
	if snapshot.get("version") != AutosaveStore.SCHEMA_VERSION:
		state.rejected_path = state.path
		state.startup_status = ("Старое сохранение несовместимо с живым районом. "
			+ "Файл сохранён; начните новое прохождение.")
		return false
	if not WorldSnapshotService.can_restore(snapshot, root):
		state.rejected_path = state.path
		state.startup_status = "Сохранение несовместимо — новое прохождение"
		return false
	if not WorldSnapshotService.restore(snapshot, root):
		state.construction_failed = true
		state.rejected_path = state.path
		state.startup_status = "Сохранение несовместимо — новое прохождение"
		return false

	state.last_saved_morning = int(snapshot.morning_day)
	state.startup_status = "Восстановлено утро %d" % state.last_saved_morning
	return true
#endregion
