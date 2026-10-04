extends Control
## Стартовый экран; игровой World создаётся только после выбора новой игры/загрузки.
class_name MainMenu

var _settings: SettingsMenu
var _load_button: Button
var _new_button: Button
var _status: Label
var _exit_dialog: ConfirmationDialog
var _level: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = GameSessionService.level_path()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSettingsService.initialize()
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.035, 0.045, 0.06, 1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var title: Label = Label.new()
	title.text = "PVZ In Hell"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	column.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "Тестовая сцена" if _level == GameSessionService.TEST_LEVEL else "Почтовое отделение"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	_new_button = _button(column, "Новая игра", "NewGame", _new_game)
	_load_button = _button(column, "Загрузить", "LoadGame", _load_game)
	_button(column, "Настройки", "Settings", _open_settings)
	_button(column, "Выйти", "Exit", _confirm_exit)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	_settings = SettingsMenu.new()
	_settings.setup_main_menu()
	_settings.closed.connect(func() -> void:
		if _new_button.is_inside_tree():
			_new_button.grab_focus()
	)
	add_child(_settings)
	_settings.set_process_unhandled_input(false)
	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.title = "Выйти из игры?"
	_exit_dialog.dialog_text = "Закрыть игру?"
	_exit_dialog.ok_button_text = "Выйти"
	_exit_dialog.cancel_button_text = "Остаться"
	_exit_dialog.confirmed.connect(func() -> void: get_tree().quit())
	add_child(_exit_dialog)

	var saved: GameSaveResult = GameSessionService.saved_game(_level)
	_load_button.disabled = not saved.success
	_status.text = saved.message
	_new_button.grab_focus()
	if OS.has_feature("qa_build"):
		print("QA menu: ", scene_file_path, "; target=", _level)
	if "--qa-startup-level" in OS.get_cmdline_user_args():
		_new_game.call_deferred()


func _button(parent: Control, caption: String, node_name: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size.y = 48.0
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _new_game() -> void:
	var error: Error = GameSessionService.start_game(get_tree(), _level)
	if error != OK:
		_status.text = "Не удалось начать игру: %s." % error_string(error)


func _load_game() -> void:
	var saved: GameSaveResult = GameSessionService.saved_game(_level)
	if not saved.success:
		_status.text = saved.message
		_load_button.disabled = true
		return

	var error: Error = GameSessionService.start_game(get_tree(), _level, saved)
	if error != OK:
		_status.text = "Не удалось загрузить: %s." % error_string(error)


func _open_settings() -> void:
	_settings.open_menu()


func _confirm_exit() -> void:
	_exit_dialog.popup_centered()
	_exit_dialog.get_cancel_button().grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _settings.is_open() or not event.is_pressed() or event.is_echo():
		return
	if GameSettingsService.is_safety_back(event):
		if _exit_dialog.visible:
			_exit_dialog.hide()
		else:
			_confirm_exit()
		get_viewport().set_input_as_handled()
