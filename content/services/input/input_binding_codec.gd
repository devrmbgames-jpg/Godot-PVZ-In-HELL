extends RefCounted
## Только переносимые данные назначений; device=-1 позволяет подключить другой геймпад.
class_name InputBindingCodec


static func is_gamepad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func encode(event: InputEvent) -> Dictionary:
	var data: Dictionary = {}
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		data = {"type": "key", "physical": int(key.physical_keycode), "logical": int(key.keycode)}
	elif event is InputEventMouseButton:
		data = {"type": "mouse", "button": int((event as InputEventMouseButton).button_index)}
	elif event is InputEventJoypadButton:
		return {"type": "button", "button": int((event as InputEventJoypadButton).button_index)}
	elif event is InputEventJoypadMotion:
		var axis: InputEventJoypadMotion = event as InputEventJoypadMotion
		return {"type": "axis", "axis": int(axis.axis), "sign": -1 if axis.axis_value < 0.0 else 1}
	else:
		return data
	var modified: InputEventWithModifiers = event as InputEventWithModifiers
	data.merge({"shift": modified.shift_pressed, "ctrl": modified.ctrl_pressed, "alt": modified.alt_pressed, "meta": modified.meta_pressed})
	return data


static func decode(data: Dictionary) -> InputEvent:
	for field: String in ["physical", "logical", "button", "axis", "sign"]:
		if data.has(field) and not data[field] is int:
			return null
	for field: String in ["shift", "ctrl", "alt", "meta"]:
		if data.has(field) and not data[field] is bool:
			return null
	if data.has("type") and not data["type"] is String:
		return null
	var event: InputEvent = null
	match String(data.get("type", "")):
		"key":
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = int(data.get("physical", 0)) as Key
			key.keycode = int(data.get("logical", 0)) as Key
			if (key.physical_keycode == 0 and key.keycode == 0) or key.physical_keycode < 0 or key.keycode < 0:
				return null
			event = key
		"mouse":
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = int(data.get("button", 0)) as MouseButton
			if mouse.button_index < MOUSE_BUTTON_LEFT or mouse.button_index > MOUSE_BUTTON_XBUTTON2:
				return null
			event = mouse
		"button":
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.button_index = int(data.get("button", -1)) as JoyButton
			if button.button_index < 0 or button.button_index >= JOY_BUTTON_MAX:
				return null
			button.device = -1
			event = button
		"axis":
			var axis: InputEventJoypadMotion = InputEventJoypadMotion.new()
			axis.axis = int(data.get("axis", -1)) as JoyAxis
			if axis.axis < 0 or axis.axis >= JOY_AXIS_MAX:
				return null
			axis.axis_value = -1.0 if int(data.get("sign", 1)) < 0 else 1.0
			axis.device = -1
			event = axis
	if event is InputEventWithModifiers:
		var modified: InputEventWithModifiers = event as InputEventWithModifiers
		modified.shift_pressed = bool(data.get("shift", false))
		modified.ctrl_pressed = bool(data.get("ctrl", false))
		modified.alt_pressed = bool(data.get("alt", false))
		modified.meta_pressed = bool(data.get("meta", false))
	return event


static func normalized(event: InputEvent) -> InputEvent:
	var copy: InputEvent = decode(encode(event))
	if copy is InputEventKey and (copy as InputEventKey).physical_keycode != 0:
		var key: InputEventKey = copy as InputEventKey
		key.keycode = 0
		# Сам Shift/Ctrl не является комбинацией клавиши с собственным модификатором.
		match key.physical_keycode:
			KEY_SHIFT: key.shift_pressed = false
			KEY_CTRL: key.ctrl_pressed = false
			KEY_ALT: key.alt_pressed = false
			KEY_META: key.meta_pressed = false
	return copy


## Runtime допускает лишние модификаторы: одинаковая клавиша/кнопка пересекается при любом chord.
## У осей знак сохраняется: противоположные направления не конфликтуют.
static func overlaps(first: InputEvent, second: InputEvent) -> bool:
	var left: InputEvent = normalized(first)
	var right: InputEvent = normalized(second)
	if left == null or right == null:
		return false
	if left is InputEventKey and right is InputEventKey:
		var left_key: InputEventKey = left as InputEventKey
		var right_key: InputEventKey = right as InputEventKey
		return (left_key.physical_keycode if left_key.physical_keycode != 0 else left_key.keycode) == (right_key.physical_keycode if right_key.physical_keycode != 0 else right_key.keycode)
	if left is InputEventMouseButton and right is InputEventMouseButton:
		return (left as InputEventMouseButton).button_index == (right as InputEventMouseButton).button_index
	return encode(left) == encode(right)
