extends Node
## Реальный SceneTree.current_scene: new/save/load/return и отказ повреждённой загрузки.

const SAVE_PATH: String = "user://r34_smoke_manual.pvzh"
const AUTO_PATH: String = "user://r34_smoke_auto.pvzh"
const SETTINGS_PATH: String = "user://r34_smoke_settings.cfg"


#region Переходы сцены и сессии через меню
## Настраивает изолированный файл предпочтений и сохраняет работу runner при паузе меню.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettingsService.initialize(SETTINGS_PATH)
	GameSettingsService.reset_defaults()
	_run.call_deferred()


## Ожидает нужную current_scene до 30 кадров и сообщает таймаут без подмены World.
func _wait_scene(path: String) -> Node:
	for frame: int in 30:
		await get_tree().process_frame
		var scene: Node = get_tree().current_scene
		if scene != null and scene.scene_file_path == path:
			return scene

	assert(false, "Scene transition timed out: " + path)
	return null


func _settings(root: Node) -> SettingsMenu:
	for node: Node in root.find_children("*", "CanvasLayer", true, false):
		if node is SettingsMenu:
			return node as SettingsMenu

	assert(false, "Settings missing")
	return null


## Проверяет new/save/load/return через настоящие кнопки; повреждённая загрузка оставляет текущую сцену.
func _run() -> void:
	# Runner остаётся под root при смене current_scene.
	get_tree().current_scene = null
	assert(get_tree().change_scene_to_file(GameSessionService.MAIN_MENU) == OK)
	var main: Node = await _wait_scene(GameSessionService.MAIN_MENU)
	assert(ECS.world == null, "Главное меню не создаёт World")
	var settings: SettingsMenu = _settings(main)
	settings.setup_main_menu(SETTINGS_PATH)
	assert(settings.open_menu())
	assert(get_tree().paused)
	settings.close_menu()
	assert(not get_tree().paused)

	var new_button: Button = main.find_child("NewGame", true, false) as Button
	assert(new_button != null)
	await _click(new_button)
	var level: Node = await _wait_scene(GameSessionService.MAIN_LEVEL)
	assert(ECS.world != null)
	var menu: SettingsMenu = _settings(level)
	menu.setup(DebugTargetResolver.player(), SETTINGS_PATH)
	menu.setup_save_paths(SAVE_PATH, AUTO_PATH)
	assert(menu.open_menu())

	var reason: String = GameSessionService.save_reason(level, menu)
	assert(reason.is_empty(), "Fresh main save allowed: " + reason)
	var save_button: Button = menu.find_child("Session_save", true, false) as Button
	assert(save_button != null and not save_button.disabled)
	await _click(save_button)
	assert(FileAccess.file_exists(SAVE_PATH))
	var saved: GameSaveResult = GameSessionService.saved_game(GameSessionService.MAIN_LEVEL, [SAVE_PATH, AUTO_PATH])
	assert(saved.success, saved.message)

	var wallet: C_Wallet = WalletService.current()
	var balance: int = wallet.balance
	wallet.balance += 123
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.DAY
	## Загрузка из меню во время смены должна восстановить сохранение в новом World.
	var load_button: Button = menu.find_child("Session_load", true, false) as Button
	GameSettingsService.set_value("mouse_sensitivity", 1.7)
	await _click(load_button)

	var confirmation: ConfirmationDialog = menu.find_child("*", true, false) as ConfirmationDialog
	## Ищем подтверждение сессии по заголовку: окно конфликта привязок существует отдельно.
	for child: Node in menu.get_children():
		if child is ConfirmationDialog and (child as ConfirmationDialog).title == "Несохранённый прогресс":
			confirmation = child as ConfirmationDialog
	assert(confirmation != null and confirmation.visible)
	confirmation.confirmed.emit()
	await get_tree().process_frame
	level = await _wait_scene(GameSessionService.MAIN_LEVEL)
	assert(DayPhaseService.current().phase == C_DayCycle.Phase.MORNING)
	assert(WalletService.current().balance == balance)
	assert(not get_tree().paused)

	var preferences: ConfigFile = ConfigFile.new()
	assert(preferences.load(SETTINGS_PATH) == OK)
	assert(is_equal_approx(float(preferences.get_value("settings", "mouse_sensitivity")), 1.7), "Load persists preferences without closing menu first")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var unavailable: GameSaveResult = GameSessionService.saved_game(GameSessionService.MAIN_LEVEL, [SAVE_PATH, AUTO_PATH])
	assert(not unavailable.success)
	assert(GameSessionService.start_game(get_tree(), GameSessionService.MAIN_LEVEL, unavailable) == ERR_INVALID_DATA)
	assert(get_tree().current_scene == level, "Bad load leaves current level intact")
	assert(GameSessionService.return_to_menu(get_tree()) == OK)
	main = await _wait_scene(GameSessionService.MAIN_MENU)
	assert(ECS.world == null, "Old world purged on return")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	for path: String in [SAVE_PATH, AUTO_PATH, SETTINGS_PATH]:
		DirAccess.remove_absolute(path)
	print("menu session smoke PASS")
	get_tree().quit()


## Посылает в viewport обычное движение мыши и пару нажатие/отпускание по центру кнопки.
func _click(button: Button) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var position: Vector2 = button.get_global_rect().get_center()
	assert(button.is_visible_in_tree())
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		get_viewport().push_input(event, true)
	await get_tree().process_frame

#endregion
