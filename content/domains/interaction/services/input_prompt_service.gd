extends RefCounted
## Иконки фактических назначений активного устройства; gamepad family определяется по имени.
class_name InputPromptService

const SIZE: Vector2 = Vector2(32, 32)
const KEY_NAMES: Dictionary[int, String] = {
	KEY_ESCAPE: "escape", KEY_TAB: "tab", KEY_SPACE: "space", KEY_ENTER: "enter",
	KEY_BACKSPACE: "backspace", KEY_DELETE: "delete", KEY_INSERT: "insert", KEY_HOME: "home",
	KEY_END: "end", KEY_PAGEUP: "page_up", KEY_PAGEDOWN: "page_down", KEY_SHIFT: "shift",
	KEY_CTRL: "ctrl", KEY_ALT: "alt", KEY_META: "command", KEY_UP: "arrow_up",
	KEY_DOWN: "arrow_down", KEY_LEFT: "arrow_left", KEY_RIGHT: "arrow_right",
	KEY_QUOTELEFT: "tilde", KEY_MINUS: "minus", KEY_EQUAL: "equals", KEY_BRACKETLEFT: "bracket_open",
	KEY_BRACKETRIGHT: "bracket_close", KEY_SEMICOLON: "semicolon", KEY_APOSTROPHE: "apostrophe",
	KEY_COMMA: "comma", KEY_PERIOD: "period", KEY_SLASH: "slash_forward", KEY_BACKSLASH: "slash_back",
}
const MOUSE_NAMES: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "mouse_left", MOUSE_BUTTON_RIGHT: "mouse_right", MOUSE_BUTTON_MIDDLE: "mouse_scroll",
	MOUSE_BUTTON_WHEEL_UP: "mouse_scroll_up", MOUSE_BUTTON_WHEEL_DOWN: "mouse_scroll_down",
	MOUSE_BUTTON_WHEEL_LEFT: "mouse_scroll", MOUSE_BUTTON_WHEEL_RIGHT: "mouse_scroll",
	MOUSE_BUTTON_XBUTTON1: "mouse_side_back", MOUSE_BUTTON_XBUTTON2: "mouse_side_forward",
}
const BUTTON_NAMES: Dictionary[int, String] = {
	JOY_BUTTON_A: "button_a", JOY_BUTTON_B: "button_b", JOY_BUTTON_X: "button_x", JOY_BUTTON_Y: "button_y",
	JOY_BUTTON_BACK: "button_back_icon", JOY_BUTTON_START: "button_start_icon", JOY_BUTTON_GUIDE: "guide",
	JOY_BUTTON_LEFT_STICK: "stick_l_press", JOY_BUTTON_RIGHT_STICK: "stick_r_press",
	JOY_BUTTON_LEFT_SHOULDER: "lb", JOY_BUTTON_RIGHT_SHOULDER: "rb",
	JOY_BUTTON_DPAD_UP: "dpad_up", JOY_BUTTON_DPAD_DOWN: "dpad_down", JOY_BUTTON_DPAD_LEFT: "dpad_left", JOY_BUTTON_DPAD_RIGHT: "dpad_right",
}
const PS_NAMES: Dictionary[String, String] = {
	"button_a": "button_cross", "button_b": "button_circle", "button_x": "button_square", "button_y": "button_triangle",
	"lb": "trigger_l1", "rb": "trigger_r1", "lt": "trigger_l2", "rt": "trigger_r2",
	"button_back_icon": "button_select", "button_start_icon": "button_start", "guide": "button_home",
}
static var _family: String = "keyboard_mouse"
static var _pad_family: String = "xbox_series"
static var _revision: int = 0


#region Устройство и ревизия
## Ревизия устройства/назначений для обновления UI по изменению вместо повторной сборки каждый кадр.
static func revision() -> int:
	return _revision


## Повышает ревизию после смены назначений или устройства; текстуры каталога сохраняются.
static func invalidate() -> void:
	_revision += 1


## Определяет семейство последнего активного устройства; небольшой шум стика/мыши не переключает подсказки.
static func observe(event: InputEvent) -> void:
	var family: String = _family
	if InputBindingCodec.is_gamepad(event):
		if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.3:
			return

		var device_name: String = Input.get_joy_name(event.device).to_lower()
		_pad_family = "playstation_series" if "playstation" in device_name or "dualshock" in device_name or "dualsense" in device_name or "sony" in device_name or "ps4" in device_name or "ps5" in device_name else "steam_deck" if "steam deck" in device_name else "steam_controller" if "steam controller" in device_name else "xbox_series"
		family = _pad_family
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0):
		family = "keyboard_mouse"
	if family != _family:
		_family = family
		invalidate()


#endregion

#region Иконки текущих назначений
## Маркер действия для InputPromptLabel; сама строка не содержит текущую привязку.
static func token(action: StringName) -> String:
	return "[input=%s]" % action


## Плоский список иконок альтернатив/модификаторов; gamepad: -1 активное устройство, 0 клавиатура, 1 геймпад.
static func textures(action: StringName, gamepad: int = -1) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for group: Array in groups(action, gamepad):
		for icon: Texture2D in group:
			result.append(icon)
	return result


## Отдельные альтернативы; внутри каждой группы сначала модификаторы, затем основная кнопка.
static func groups(action: StringName, gamepad: int = -1) -> Array[Array]:
	var result: Array[Array] = []
	if not InputMap.has_action(action):
		return result

	var pad: bool = _family != "keyboard_mouse" if gamepad < 0 else gamepad == 1
	var family: String = _pad_family if pad else "keyboard_mouse"
	for event: InputEvent in InputMap.action_get_events(action):
		if InputBindingCodec.is_gamepad(event) != pad:
			continue

		var icons: Array[Texture2D] = []
		if event is InputEventWithModifiers:
			var modified: InputEventWithModifiers = event as InputEventWithModifiers
			for pair: Array in [[modified.ctrl_pressed, "ctrl"], [modified.alt_pressed, "alt"], [modified.shift_pressed, "shift"], [modified.meta_pressed, "command"]]:
				if bool(pair[0]):
					icons.append(InputPromptCatalog.texture("keyboard_mouse", "keyboard_" + String(pair[1])))
		var texture: Texture2D = texture_for(event, family)
		if texture != null:
			icons.append(texture)
		if not icons.is_empty():
			result.append(icons)
	return result


## Иконка конкретной кнопки/оси с fallback на устройство или клавиатуру при отсутствии спрайта.
static func texture_for(event: InputEvent, family: String = "keyboard_mouse") -> Texture2D:
	var name: String = ""
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: int = int(key.physical_keycode if key.physical_keycode != 0 else key.keycode)
		var suffix: String = KEY_NAMES.get(code, "")
		if suffix.is_empty() and ((code >= KEY_A and code <= KEY_Z) or (code >= KEY_0 and code <= KEY_9)):
			suffix = String.chr(code).to_lower()
		if code >= KEY_F1 and code <= KEY_F12:
			suffix = "f%d" % (code - KEY_F1 + 1)
		name = "keyboard_" + suffix if not suffix.is_empty() else "keyboard_any"
		family = "keyboard_mouse"
	elif event is InputEventMouseButton:
		name = MOUSE_NAMES.get(int((event as InputEventMouseButton).button_index), "mouse")
		family = "keyboard_mouse"
	elif event is InputEventJoypadButton:
		name = BUTTON_NAMES.get(int((event as InputEventJoypadButton).button_index), "")
	elif event is InputEventJoypadMotion:
		var axis: InputEventJoypadMotion = event as InputEventJoypadMotion
		match axis.axis:
			JOY_AXIS_TRIGGER_LEFT: name = "lt"
			JOY_AXIS_TRIGGER_RIGHT: name = "rt"
			JOY_AXIS_LEFT_X: name = "stick_l_left" if axis.axis_value < 0 else "stick_l_right"
			JOY_AXIS_LEFT_Y: name = "stick_l_up" if axis.axis_value < 0 else "stick_l_down"
			JOY_AXIS_RIGHT_X: name = "stick_r_left" if axis.axis_value < 0 else "stick_r_right"
			JOY_AXIS_RIGHT_Y: name = "stick_r_up" if axis.axis_value < 0 else "stick_r_down"

	if family != "keyboard_mouse":
		var prefix: String = "playstation" if family == "playstation_series" else "steamdeck" if family == "steam_deck" else "steam" if family == "steam_controller" else "xbox"
		if family == "playstation_series":
			if name == "button_back_icon":
				name = "playstation4_button_share"
				prefix = ""
			elif name == "button_start_icon":
				name = "playstation4_button_options"
				prefix = ""
			elif name == "guide":
				name = "controller_playstation5"
				prefix = ""
			else:
				name = PS_NAMES.get(name, name)
		elif family == "steam_deck":
			name = {"lb": "button_l1", "rb": "button_r1", "lt": "button_l2", "rt": "button_r2", "button_back_icon": "button_view", "button_start_icon": "button_options", "guide": "button_guide"}.get(name, name)
		elif family == "steam_controller":
			if name.begins_with("stick_l_") and name != "stick_l_press":
				name = name.replace("stick_l_", "stick_")
			elif name.begins_with("stick_r_"):
				name = name.replace("stick_r_", "pad_")
		name = prefix + "_" + name if not prefix.is_empty() else name

	var result: Texture2D = InputPromptCatalog.texture(family, name)
	if result != null:
		return result

	if family != "keyboard_mouse":
		var fallback: String = {"xbox_series": "controller_xboxseries", "playstation_series": "controller_playstation5", "steam_deck": "controller_steamdeck", "steam_controller": "controller_steam"}.get(family, "controller_xboxseries")
		result = InputPromptCatalog.texture(family, fallback)
	return result if result != null else InputPromptCatalog.texture("keyboard_mouse", "keyboard_any")

#endregion
