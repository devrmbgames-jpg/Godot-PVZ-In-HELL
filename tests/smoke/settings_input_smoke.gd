extends Node
## Реальный main HUD: открыть меню raw input, capture клавиши/отрицательной оси, cancel и возврат.

const TEST_PATH: String = "user://r30_settings_smoke.cfg"
var _level: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event


func _run() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	_level.set("autosave_path", "")
	add_child(_level)
	await get_tree().process_frame
	var menu: SettingsMenu = null
	for node: Node in _level.find_children("*", "CanvasLayer", true, false):
		if node is SettingsMenu:
			menu = node as SettingsMenu
	assert(menu != null)

	var actor: Entity = DebugTargetResolver.player()
	menu.setup(actor, TEST_PATH)
	print("settings fixture: live=%s focus=%s console=%s input=%s" % [EntityAvailability.contains(actor, ECS.world), InteractionControlFocus.current(actor), Console.is_visible(), menu.is_processing_unhandled_input()])
	await _send(_key(KEY_ESCAPE))
	assert(get_tree().paused, "Raw safety key opens actual main settings")
	assert(InteractionControlFocus.current(actor) == InteractionControlFocus.Priority.MODAL)
	await _send(_key(KEY_ESCAPE, false))
	var interact_button: Button = _binding_button(menu, "Взаимодействие", 0)
	interact_button.pressed.emit()
	await _send(_key(KEY_K))
	await _send(_key(KEY_K, false))
	assert(InputMap.action_has_event(&"interact", _key(KEY_K)))

	var look_button: Button = _binding_button(menu, "Камера влево", 1)
	look_button.pressed.emit()
	var axis: InputEventJoypadMotion = InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_RIGHT_X
	axis.axis_value = -1.0
	await _send(axis)
	assert(InputMap.action_has_event(&"look_left", axis), "Negative axis capture is supported")
	var prompt: Array[Texture2D] = InputPromptService.textures(&"look_left", 1)
	assert(not prompt.is_empty() and prompt[0].resource_path.ends_with("xbox_stick_r_left.png"))
	interact_button.pressed.emit()
	await _send(_key(KEY_ESCAPE))
	await _send(_key(KEY_ESCAPE, false))
	assert(get_tree().paused, "Cancel binding keeps menu open")
	assert(InputMap.action_has_event(&"interact", _key(KEY_K)), "Cancel preserves last binding")
	await _send(_key(KEY_ESCAPE))
	await _send(_key(KEY_ESCAPE, false))
	assert(not get_tree().paused, "Safety exit resumes actual main")
	assert(InteractionControlFocus.current(actor) < InteractionControlFocus.Priority.MODAL)
	assert(FileAccess.file_exists(TEST_PATH))
	GameSettingsService.reset_defaults()
	DirAccess.remove_absolute(TEST_PATH)
	_level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("settings input smoke PASS")
	get_tree().quit()


func _binding_button(menu: SettingsMenu, caption: String, device: int) -> Button:
	for node: Node in menu.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text == caption and label.get_parent() is HBoxContainer:
			return label.get_parent().get_child(device + 1) as Button

	assert(false, "Binding row missing: " + caption)
	return null


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await get_tree().process_frame
