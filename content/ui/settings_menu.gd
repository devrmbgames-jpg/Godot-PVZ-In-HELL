extends CanvasLayer
## Модальное меню пользователя; приостановка мира принадлежит только открытому меню.
class_name SettingsMenu

const CAPTURE_THRESHOLD: float = 0.65
const PANEL_SIZE: Vector2 = Vector2(900, 650)

var _actor: Entity
var _root: Control
var _rows: VBoxContainer
var _status: Label
var _close: Button
var _conflict: ConfirmationDialog
var _capture: int = 0
var _previous_mouse: Input.MouseMode
var _previous_pause: bool = false
var _await_action: StringName = &""
var _await_pad: bool = false
var _pending: InputEvent
var _binding_buttons: Dictionary[Button, Array] = {}
var _revision: int = -1
var _settings_path: String = GameSettingsService.FILE_PATH


func setup(actor: Entity, settings_path: String = GameSettingsService.FILE_PATH) -> void:
	_actor = actor
	_settings_path = settings_path


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	GameSettingsService.initialize(_settings_path)
	_root = CenterContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	_root.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	panel.add_child(content)
	var title: Label = Label.new()
	title.text = "Настройки"
	content.add_child(title)
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	var settings: VBoxContainer = VBoxContainer.new()
	settings.name = "Игра"
	tabs.add_child(settings)
	_slider(settings, "Громкость", "volume", 0.0, 1.0, 0.05)
	_slider(settings, "Чувствительность мыши", "mouse_sensitivity", 0.1, 4.0, 0.1)
	_slider(settings, "Чувствительность геймпада", "gamepad_sensitivity", 0.1, 4.0, 0.1)
	_slider(settings, "Мёртвая зона стиков", "deadzone", 0.05, 0.75, 0.05)
	_toggle(settings, "Бег: переключение (выключено — удерживать)", "sprint_toggle")
	_toggle(settings, "Полный экран", "fullscreen")
	_toggle(settings, "Вертикальная синхронизация", "vsync")
	_toggle(settings, "Уменьшить движение камеры и виньетки", "reduced_motion")
	var controls: ScrollContainer = ScrollContainer.new()
	controls.name = "Управление"
	controls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(controls)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(_rows)
	_build_controls()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	var reset: Button = Button.new()
	reset.text = "Восстановить настройки и управление"
	reset.pressed.connect(_reset)
	content.add_child(reset)
	_close = Button.new()
	_close.text = "Сохранить и вернуться"
	_close.pressed.connect(close_menu)
	content.add_child(_close)
	_conflict = ConfirmationDialog.new()
	_conflict.title = "Кнопка уже назначена"
	_conflict.ok_button_text = "Переназначить"
	_conflict.cancel_button_text = "Отмена"
	_conflict.confirmed.connect(_confirm_binding)
	_conflict.canceled.connect(_cancel_binding)
	add_child(_conflict)
	_root.hide()


func _exit_tree() -> void:
	_release()


func _unhandled_input(event: InputEvent) -> void:
	if _capture == 0 and event.is_pressed() and not event.is_echo() and (event.is_action_pressed(&"menu") or GameSettingsService.is_safety_back(event)):
		if open_menu():
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	InputPromptService.observe(event)
	if _capture == 0 or bool(Console.is_visible()) or (not event.is_pressed() and not event is InputEventJoypadMotion) or event.is_echo():
		return
	if GameSettingsService.is_safety_back(event):
		if _await_action != &"":
			_conflict.hide()
			_cancel_binding()
		else:
			close_menu()
		get_viewport().set_input_as_handled()
		return
	if _await_action == &"":
		if event.is_action_pressed(&"menu"):
			close_menu()
			get_viewport().set_input_as_handled()
		return
	if _pending != null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and _close.get_global_rect().has_point((event as InputEventMouseButton).position):
		_cancel_binding()
		get_viewport().set_input_as_handled()
		return
	# Capture cannot reach UI navigation or gameplay, including unsupported device events.
	get_viewport().set_input_as_handled()
	if InputBindingCodec.is_gamepad(event) != _await_pad:
		return
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < CAPTURE_THRESHOLD:
		return
	if event is InputEventKey and _await_action != &"sprint" and (event as InputEventKey).physical_keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	_pending = InputBindingCodec.normalized(event)
	if _pending == null:
		return
	var conflicts: Array[StringName] = GameSettingsService.conflicts(_await_action, _pending)
	if conflicts.is_empty():
		_confirm_binding()
	else:
		var names: PackedStringArray = []
		for action: StringName in conflicts:
			names.append(GameSettingsService.ACTIONS[action])
		_conflict.dialog_text = "Удалить эту кнопку из действий: %s?" % ", ".join(names)
		_conflict.popup_centered()


func _process(_delta: float) -> void:
	if _capture != 0 and not is_instance_valid(_actor):
		close_menu()
	if _revision == InputPromptService.revision():
		return
	_revision = InputPromptService.revision()
	for button: Button in _binding_buttons:
		var binding: Array = _binding_buttons[button]
		var icons: Array[AtlasTexture] = InputPromptService.textures(StringName(binding[0]), int(binding[1]))
		var hint: InputPromptLabel = button.get_node("BindingHint") as InputPromptLabel
		hint.visible = not icons.is_empty()
		button.text = "" if not icons.is_empty() else "Не назначено"
		button.tooltip_text = "Заменить назначения для этого устройства"
	var close_icons: Array[AtlasTexture] = InputPromptService.textures(&"menu")
	_close.icon = close_icons[0] if not close_icons.is_empty() else null


func open_menu() -> bool:
	if _capture != 0 or not EntityAvailability.contains(_actor, ECS.world) or bool(Console.is_visible()) or InteractionControlFocus.current(_actor) >= InteractionControlFocus.Priority.DRAWING:
		return false
	_capture = InteractionControlFocus.acquire(_actor, self, InteractionControlFocus.Priority.MODAL)
	if _capture == 0:
		return false
	_previous_pause = get_tree().paused
	_previous_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.show()
	_status.text = "Выберите действие и устройство. Кнопка возврата всегда отменяет ввод."
	_close.grab_focus()
	return true


func close_menu() -> void:
	if _capture == 0:
		return
	GameSettingsService.apply()
	var error: Error = GameSettingsService.save(_settings_path)
	if error != OK:
		push_warning("Не удалось сохранить настройки: %s" % error_string(error))
	_cancel_binding()
	_conflict.hide()
	_root.hide()
	_release()


func _release() -> void:
	if _capture == 0:
		return
	InteractionControlFocus.release(_actor, _capture)
	_capture = 0
	get_tree().paused = _previous_pause
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if bool(Console.is_visible()) else _previous_mouse


func _build_controls() -> void:
	var heading: Label = Label.new()
	heading.text = "Действие                                  Клавиатура / мышь               Геймпад"
	_rows.add_child(heading)
	for action: StringName in GameSettingsService.ACTIONS:
		if not InputMap.has_action(action):
			continue
		var row: HBoxContainer = HBoxContainer.new()
		_rows.add_child(row)
		var label: Label = Label.new()
		label.text = GameSettingsService.ACTIONS[action]
		label.custom_minimum_size.x = 370.0
		row.add_child(label)
		for pad: int in [0, 1]:
			var button: Button = Button.new()
			button.custom_minimum_size = Vector2(190, 40)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 32)
			row.add_child(button)
			var hint: InputPromptLabel = InputPromptLabel.new()
			hint.name = "BindingHint"
			hint.binding_device = pad
			hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.add_child(hint)
			hint.set_prompt(InputPromptService.token(action))
			_binding_buttons[button] = [action, pad]
			button.pressed.connect(_capture_binding.bind(action, pad == 1))


func _capture_binding(action: StringName, pad: bool) -> void:
	_await_action = action
	_await_pad = pad
	_pending = null
	_status.text = "Нажмите новую кнопку%s для «%s». Кнопка возврата — отмена." % [" или отклоните стик" if pad else "", GameSettingsService.ACTIONS[action]]
	_close.text = "Отменить назначение"


func _confirm_binding() -> void:
	if _pending != null and GameSettingsService.rebind(_await_action, _pending, true):
		_status.text = "Назначение изменено. Настройки сохраняются при выходе."
	else:
		_status.text = "Кнопка зарезервирована для меню или консоли. Выберите другую."
	_await_action = &""
	_pending = null
	_close.text = "Сохранить и вернуться"


func _cancel_binding() -> void:
	_await_action = &""
	_pending = null
	_close.text = "Сохранить и вернуться"
	if _status != null:
		_status.text = "Изменения управления отменены."


func _slider(parent: Control, title: String, key: String, minimum: float, maximum: float, step_size: float) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.custom_minimum_size.x = 350
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_size
	slider.value = float(GameSettingsService.value(key))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	label.text = "%s: %.2f" % [title, slider.value]
	slider.value_changed.connect(func(number: float) -> void:
		GameSettingsService.set_value(key, number)
		GameSettingsService.apply()
		label.text = "%s: %.2f" % [title, number]
	)
	slider.set_meta("setting_key", key)


func _toggle(parent: Control, title: String, key: String) -> void:
	var check: CheckButton = CheckButton.new()
	check.text = title
	check.button_pressed = bool(GameSettingsService.value(key))
	parent.add_child(check)
	check.toggled.connect(func(enabled: bool) -> void:
		GameSettingsService.set_value(key, enabled)
		GameSettingsService.apply()
	)
	check.set_meta("setting_key", key)


func _reset() -> void:
	GameSettingsService.reset_defaults()
	for node: Node in _root.find_children("*", "Range", true, false):
		var key: String = String(node.get_meta("setting_key", ""))
		if not key.is_empty():
			(node as Range).value = float(GameSettingsService.value(key))
	for node: Node in _root.find_children("*", "CheckButton", true, false):
		var key: String = String(node.get_meta("setting_key", ""))
		if not key.is_empty():
			(node as CheckButton).button_pressed = bool(GameSettingsService.value(key))
	_status.text = "Восстановлены исходные настройки и назначения."
