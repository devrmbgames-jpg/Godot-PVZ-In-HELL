extends RefCounted
## Настройки пользователя и InputMap; настройки не входят в игровые snapshots.
class_name GameSettingsService

const FILE_PATH: String = "user://settings.cfg"
const MAX_BINDINGS_PER_ACTION: int = 16
const ACTIONS: Dictionary[StringName, String] = {
	&"forward": "Вперёд", &"back": "Назад", &"left": "Влево", &"right": "Вправо",
	&"jump": "Прыжок", &"crouch": "Присесть", &"interact": "Взаимодействие",
	&"use": "Использовать", &"action_primary": "Основное действие", &"action_secondary": "Второе действие",
	&"physical_override": "Бросок / силовое действие", &"rotate_held": "Вращать предмет",
	&"drop": "Положить / удерживать для броска", &"inventory": "Инвентарь", &"menu": "Настройки / закрыть",
	&"look_left": "Камера влево", &"look_right": "Камера вправо", &"look_up": "Камера вверх", &"look_down": "Камера вниз",
}
const DEFAULTS: Dictionary[String, Variant] = {
	"volume": 1.0, "fullscreen": false, "vsync": true, "reduced_motion": false,
	"mouse_sensitivity": 1.0, "gamepad_sensitivity": 1.0, "deadzone": 0.2,
}

static var _initialized: bool = false
static var _defaults: Dictionary[StringName, Array] = {}
static var _values: Dictionary[String, Variant] = DEFAULTS.duplicate()


static func initialize(path: String = FILE_PATH) -> void:
	if _initialized:
		return
	_initialized = true
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			_defaults[action] = InputMap.action_get_events(action).duplicate(true)
	load_settings(path)
	apply()


static func value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


static func set_value(key: String, setting: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	if DEFAULTS[key] is bool:
		if setting is bool:
			_values[key] = setting
	else:
		if not setting is int and not setting is float:
			return
		var number: float = float(setting)
		if not is_finite(number):
			return
		_values[key] = clampf(number, 0.0, 1.0) if key == "volume" else clampf(number, 0.05, 0.75) if key == "deadzone" else clampf(number, 0.1, 4.0)


static func apply() -> void:
	AudioServer.set_bus_volume_linear(0, float(value("volume")))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(value("fullscreen")) else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(value("vsync")) else DisplayServer.VSYNC_DISABLED)
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, float(value("deadzone")))


## Возвращает конфликты, не меняя InputMap; игрок подтверждает их удаление явно.
static func conflicts(action: StringName, event: InputEvent) -> Array[StringName]:
	var result: Array[StringName] = []
	var candidate: InputEvent = InputBindingCodec.normalized(event)
	if candidate == null:
		return result
	for other: StringName in ACTIONS:
		if other == action or not InputMap.has_action(other):
			continue
		for existing: InputEvent in InputMap.action_get_events(other):
			if InputBindingCodec.overlaps(existing, candidate):
				result.append(other)
				break
	return result


## Заменяет назначения выбранного устройства; другой тип устройства сохраняется.
static func rebind(action: StringName, event: InputEvent, resolve_conflicts: bool = false) -> bool:
	if not ACTIONS.has(action) or not InputMap.has_action(action):
		return false
	var candidate: InputEvent = InputBindingCodec.normalized(event)
	if candidate == null or is_safety_back(candidate):
		return false
	if candidate is InputEventKey:
		var key: InputEventKey = candidate as InputEventKey
		if key.physical_keycode == KEY_QUOTELEFT or key.keycode == KEY_QUOTELEFT:
			return false
	var blocked: Array[StringName] = conflicts(action, candidate)
	if not blocked.is_empty() and not resolve_conflicts:
		return false
	for other: StringName in blocked:
		for existing: InputEvent in InputMap.action_get_events(other):
			if InputBindingCodec.overlaps(existing, candidate):
				InputMap.action_erase_event(other, existing)
	for existing: InputEvent in InputMap.action_get_events(action):
		if InputBindingCodec.is_gamepad(existing) == InputBindingCodec.is_gamepad(candidate) and not is_safety_back(existing):
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, candidate)
	InputPromptService.invalidate()
	return true


## Escape и Back всегда позволяют отменить capture/выйти, независимо от пользовательских назначений.
static func is_safety_back(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE
	return event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_BACK


static func reset_defaults() -> void:
	_values.assign(DEFAULTS)
	for action: StringName in _defaults:
		InputMap.action_erase_events(action)
		for event: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, event.duplicate() as InputEvent)
	apply()
	InputPromptService.invalidate()


static func save(path: String = FILE_PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	for key: String in _values:
		config.set_value("settings", key, _values[key])
	for action: StringName in ACTIONS:
		var bindings: Array[Dictionary] = []
		for event: InputEvent in InputMap.action_get_events(action):
			var data: Dictionary = InputBindingCodec.encode(event)
			if not data.is_empty():
				bindings.append(data)
		config.set_value("input", String(action), bindings)
	return config.save(path)


static func load_settings(path: String = FILE_PATH) -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return
	for key: String in DEFAULTS:
		set_value(key, config.get_value("settings", key, DEFAULTS[key]))
	for action: StringName in ACTIONS:
		if not config.has_section_key("input", String(action)):
			continue
		var stored: Variant = config.get_value("input", String(action))
		if not stored is Array or not InputMap.has_action(action) or (stored as Array).size() > MAX_BINDINGS_PER_ACTION:
			continue
		var decoded: Array[InputEvent] = []
		var valid: bool = true
		for data: Variant in stored as Array:
			var event: InputEvent = InputBindingCodec.decode(data as Dictionary) if data is Dictionary else null
			if event == null:
				valid = false
				break
			decoded.append(event)
		if valid:
			InputMap.action_erase_events(action)
			for event: InputEvent in decoded:
				InputMap.action_add_event(action, event)
	InputPromptService.invalidate()
