extends RefCounted
## Игровые слоты и одноразовая передача snapshot при смене сцены; Entity-ссылок не хранит.
class_name GameSessionService

const MAIN_MENU: String = "res://content/ui/main_menu.tscn"
const MAIN_LEVEL: String = "res://content/scenes/main_level.tscn"
const TEST_LEVEL: String = "res://content/scenes/primitive_test_level.tscn"
const MANUAL_SAVE: String = "user://manual_save.pvzh"
const TEST_MANUAL_SAVE: String = "user://primitive_manual_save.pvzh"
const TEST_AUTOSAVE: String = "user://primitive_test_level.pvzh"

static var _pending_level: String = ""
static var _pending_snapshot: Dictionary = {}


#region Пути игровых слотов
## Выбирает основной или тестовый уровень по признаку QA-сборки.
static func level_path() -> String:
	return TEST_LEVEL if OS.has_feature("qa_test_level") else MAIN_LEVEL


## Возвращает отдельный ручной слот для основного/тестового уровня.
static func manual_path(level: String) -> String:
	return TEST_MANUAL_SAVE if level == TEST_LEVEL else MANUAL_SAVE


## Возвращает отдельный автоматический слот для основного/тестового уровня.
static func autosave_path(level: String) -> String:
	return TEST_AUTOSAVE if level == TEST_LEVEL else AutosaveStore.DEFAULT_PATH


#endregion

#region Ручное сохранение и выбор слота
## Собственный modal token меню можно исключить; другие захваты и живые связи остаются запретом.
static func save_reason(root: Node, menu_owner: Object = null) -> String:
	if root == null or not is_instance_valid(ECS.world) or ECS.world.get_parent() != root:
		return "Игровой уровень недоступен."
	if root.scene_file_path not in [MAIN_LEVEL, TEST_LEVEL]:
		return "Для этой сцены нет игрового слота."

	var cycle: C_DayCycle = DayPhaseQueries.current()
	if cycle == null or cycle.phase != C_DayCycle.Phase.MORNING:
		return "Сохранение доступно утром, перед началом смены."
	if not ECS.world.query.with_all([C_CustomerAgent]).with_none([C_Death]).execute().is_empty():
		return "Дождитесь ухода посетителей."

	for actor: Entity in ECS.world.entities:
		if not is_instance_valid(actor):
			continue

		var challenge: C_Challenge = actor.get_component(C_Challenge) as C_Challenge
		if challenge != null and challenge.phase in [C_Challenge.Phase.ARMED, C_Challenge.Phase.ACTIVE]:
			return "Завершите активное испытание."

		var control: C_GrabControl = actor.get_component(C_GrabControl) as C_GrabControl
		if control != null:
			for capture: InteractionControlCapture in control.captures.values():
				var owner: Object = capture.owner.get_ref() if capture.owner != null else null
				if owner != null and owner != menu_owner and capture.priority > InteractionControlFocus.Priority.HANDS:
					return "Завершите взаимодействие и положите предметы из рук."

		for binding: Relationship in actor.relationships:
			if binding.relation is R_HeldBy or binding.relation is R_ProlongedOn or binding.relation is R_PushedBy or binding.relation is R_CartDrivenBy:
				return "Положите предметы из рук и завершите взаимодействие."
	return ""


## Сохраняет допустимое утро после проверки восстановления; отказ сохраняет прежний слот.
static func save_game(root: Node, menu_owner: Object = null, path_override: String = "") -> GameSaveResult:
	var result: GameSaveResult = GameSaveResult.new()
	result.message = save_reason(root, menu_owner)
	if not result.message.is_empty():
		return result

	var cycle: C_DayCycle = DayPhaseQueries.current()
	var snapshot: Dictionary = WorldSnapshotService.capture(root, cycle.day_index)
	snapshot["level_scene"] = root.scene_file_path
	if not WorldSnapshotService.can_restore(snapshot, root):
		result.message = "Состояние уровня нельзя сохранить. Предыдущее сохранение осталось на месте."
		return result

	result.path = manual_path(root.scene_file_path) if path_override.is_empty() else path_override
	var error: Error = AutosaveStore.write(snapshot, result.path)
	result.success = error == OK
	result.message = "Сохранено: утро %d." % cycle.day_index if result.success else "Не удалось сохранить: %s." % error_string(error)
	return result


## Выбирает последнее совместимое manual/auto; испорченный новый файл не скрывает исправный старый.
static func saved_game(level: String, path_overrides: Array[String] = []) -> GameSaveResult:
	var result: GameSaveResult = GameSaveResult.new()
	if level not in [MAIN_LEVEL, TEST_LEVEL]:
		result.message = "Неизвестный уровень."
		return result

	var packed: PackedScene = load(level) as PackedScene
	if packed == null:
		result.message = "Не удалось открыть уровень."
		return result

	var probe: Node = packed.instantiate()
	var paths: Array[String] = []
	if path_overrides.is_empty():
		paths.assign([manual_path(level), autosave_path(level)])
	else:
		paths.assign(path_overrides)
	var manual_slot: String = manual_path(level) if path_overrides.is_empty() else path_overrides[0]
	paths.sort_custom(func(left: String, right: String) -> bool: return FileAccess.get_modified_time(left) > FileAccess.get_modified_time(right))

	var found_file: bool = false
	var incompatible_version: bool = false
	for path: String in paths:
		if not FileAccess.file_exists(path):
			continue

		found_file = true
		var data: Dictionary = AutosaveStore.read(path)
		if not data.is_empty() and data.get("version") != AutosaveStore.SCHEMA_VERSION:
			incompatible_version = true
		if data.is_empty() or data.get("level_scene", level) != level or not WorldSnapshotService.can_restore(data, probe):
			continue

		result.success = true
		result.path = path
		result.snapshot = data
		result.message = "%s · утро %d" % ["Ручное сохранение" if path == manual_slot else "Автосохранение", int(data.morning_day)]
		break

	probe.free()
	if not result.success:
		result.message = "Сохранение повреждено или несовместимо." if found_file else "Сохранений пока нет."
		if incompatible_version:
			result.message = "Старый формат несовместим с живым районом. Файл сохранён; начните новое прохождение."
	return result


#endregion

#region Передача снимка и смена сцены
## Returns a detached startup candidate without consuming the one-shot scene handoff.
static func startup_snapshot(root: Node, path: String) -> Dictionary:
	if _pending_level == root.scene_file_path:
		return _pending_snapshot.duplicate(true)
	return AutosaveStore.read(path) if not path.is_empty() else {}


## Предварительная проверка происходит до закрытия текущей сцены. Новый старт не удаляет слоты.
static func start_game(tree: SceneTree, level: String, saved: GameSaveResult = null) -> Error:
	if level not in [MAIN_LEVEL, TEST_LEVEL]:
		return ERR_INVALID_PARAMETER

	var packed: PackedScene = load(level) as PackedScene
	if packed == null:
		return ERR_CANT_OPEN
	if saved != null:
		if not saved.success or saved.snapshot.is_empty() or saved.snapshot.get("level_scene", level) != level:
			return ERR_INVALID_DATA

		var probe: Node = packed.instantiate()
		var compatible: bool = WorldSnapshotService.can_restore(saved.snapshot, probe)
		probe.free()
		if not compatible:
			return ERR_INVALID_DATA

	var was_paused: bool = tree.paused
	_pending_level = level
	_pending_snapshot = saved.snapshot.duplicate(true) if saved != null else {}
	tree.paused = false
	var error: Error = tree.change_scene_to_packed(packed)
	if error != OK:
		_pending_level = ""
		_pending_snapshot = {}
		tree.paused = was_paused
	return error


## Вызывается новым уровнем после регистрации World; F6-сцены сохраняют прежний auto-restore.
static func restore_startup(root: Node, state: C_Autosave) -> void:
	if _pending_level != root.scene_file_path:
		NightSaveService.restore_startup(root, state)
		return

	var snapshot: Dictionary = _pending_snapshot
	_pending_level = ""
	_pending_snapshot = {}
	if snapshot.is_empty():
		state.startup_status = "Новое прохождение"
	else:
		# A selected compatible manual slot does not authorize overwriting an
		# incompatible automatic slot previously rejected by the selection scan.
		if FileAccess.file_exists(state.path):
			var automatic: Dictionary = AutosaveStore.read(state.path)
			if not WorldSnapshotService.can_restore(automatic, root):
				state.rejected_path = state.path
		if WorldSnapshotService.restore(snapshot, root):
			state.last_saved_morning = int(snapshot.morning_day)
			state.startup_status = "Восстановлено утро %d" % state.last_saved_morning
		else:
			state.construction_failed = true
			state.startup_status = "Не удалось восстановить сохранение"
			push_error(state.startup_status)


## Снимает паузу и меняет сцену; ошибка восстанавливает прежнее состояние паузы.
static func return_to_menu(tree: SceneTree) -> Error:
	var was_paused: bool = tree.paused
	tree.paused = false
	var error: Error = tree.change_scene_to_file(MAIN_MENU)
	if error != OK:
		tree.paused = was_paused
	return error

#endregion
