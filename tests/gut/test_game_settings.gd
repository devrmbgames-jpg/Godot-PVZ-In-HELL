extends GutTest
## Настройки/назначения через реальные InputMap, ConfigFile, Texture2D и modal lifecycle.

const TEST_PATH: String = "user://r30_settings_test.cfg"
var _events: Dictionary[StringName, Array] = {}
var _mouse: Input.MouseMode


func before_each() -> void:
	_mouse = Input.mouse_mode
	for action: StringName in GameSettingsService.ACTIONS:
		_events[action] = InputMap.action_get_events(action).duplicate(true)
	GameSettingsService.initialize(TEST_PATH)
	GameSettingsService.reset_defaults()


func after_each() -> void:
	GameSettingsService.reset_defaults()
	for action: StringName in _events:
		InputMap.action_erase_events(action)
		for event: InputEvent in _events[action]:
			InputMap.action_add_event(action, event)
	DirAccess.remove_absolute(TEST_PATH)
	Input.mouse_mode = _mouse
	get_tree().paused = false
	ECS.world = null
	InputPromptService.invalidate()


func _key(code: Key, ctrl: bool = false) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = code
	key.ctrl_pressed = ctrl
	key.pressed = true
	return key


func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event


func test_conflict_requires_confirmation_and_preserves_other_device_and_safety_exit() -> void:
	var original: Array[InputEvent] = InputMap.action_get_events(&"interact")
	assert_false(GameSettingsService.rebind(&"interact", _key(KEY_SPACE)))
	assert_eq(InputMap.action_get_events(&"interact"), original)
	assert_true(GameSettingsService.rebind(&"interact", _key(KEY_SPACE), true))
	assert_false(InputMap.action_has_event(&"jump", _key(KEY_SPACE)))
	var joy: InputEventJoypadButton = InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_X
	assert_true(InputMap.action_has_event(&"interact", joy), "Keyboard remap preserves gamepad")
	assert_false(GameSettingsService.rebind(&"interact", _key(KEY_ESCAPE), true))
	joy.button_index = JOY_BUTTON_BACK
	assert_false(GameSettingsService.rebind(&"interact", joy, true))
	assert_true(GameSettingsService.is_safety_back(_key(KEY_ESCAPE)))
	assert_true(GameSettingsService.is_safety_back(joy))


func test_modifier_overlap_matches_runtime_and_confirm_removes_unmodified_action() -> void:
	var chord: InputEventKey = _key(KEY_E, true)
	assert_true(InputMap.event_is_action(chord, &"interact"), "Runtime permits extra Ctrl on the unmodified E binding")
	assert_true(&"interact" in GameSettingsService.conflicts(&"jump", chord))
	assert_false(GameSettingsService.rebind(&"jump", chord))
	assert_true(GameSettingsService.rebind(&"jump", chord, true))
	assert_true(InputMap.event_is_action(chord, &"jump"))
	assert_false(InputMap.event_is_action(chord, &"interact"), "Confirmed removal prevents both runtime actions firing")


func test_axis_direction_and_modifier_are_separate_bindings() -> void:
	assert_true(GameSettingsService.rebind(&"look_left", _axis(JOY_AXIS_RIGHT_X, -1.0)))
	assert_false(&"look_right" in GameSettingsService.conflicts(&"look_left", _axis(JOY_AXIS_RIGHT_X, -1.0)))
	assert_true(GameSettingsService.rebind(&"interact", _key(KEY_K, true)))
	assert_false(InputMap.action_has_event(&"interact", _key(KEY_K)))
	assert_true(InputMap.action_has_event(&"interact", _key(KEY_K, true)))
	var textures: Array[Texture2D] = InputPromptService.textures(&"interact", 0)
	assert_eq(textures.size(), 2, "Modifier and main key use individual icons")


func test_settings_and_input_survive_config_roundtrip_and_reset() -> void:
	assert_true(GameSettingsService.rebind(&"interact", _key(KEY_K, true)))
	assert_true(GameSettingsService.rebind(&"look_up", _axis(JOY_AXIS_LEFT_Y, -1.0), true))
	GameSettingsService.set_value("volume", 0.4)
	GameSettingsService.set_value("deadzone", 0.35)
	GameSettingsService.set_value("mouse_sensitivity", 2.0)
	GameSettingsService.set_value("reduced_motion", true)
	assert_eq(GameSettingsService.save(TEST_PATH), OK)
	GameSettingsService.reset_defaults()
	assert_eq(GameSettingsService.value("mouse_sensitivity"), 1.0)
	GameSettingsService.load_settings(TEST_PATH)
	assert_true(InputMap.action_has_event(&"interact", _key(KEY_K, true)))
	assert_true(InputMap.action_has_event(&"look_up", _axis(JOY_AXIS_LEFT_Y, -1.0)))
	assert_eq(GameSettingsService.value("volume"), 0.4)
	assert_eq(GameSettingsService.value("deadzone"), 0.35)
	assert_eq(GameSettingsService.value("mouse_sensitivity"), 2.0)
	assert_eq(GameSettingsService.value("reduced_motion"), true)


func test_invalid_bindings_keep_defaults_and_settings_are_bounded() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("input", "interact", [{"type": "axis", "axis": -1}])
	assert_eq(config.save(TEST_PATH), OK)
	var defaults: Array[InputEvent] = InputMap.action_get_events(&"interact")
	GameSettingsService.load_settings(TEST_PATH)
	assert_eq(InputMap.action_get_events(&"interact"), defaults)
	GameSettingsService.set_value("deadzone", 50)
	assert_eq(GameSettingsService.value("deadzone"), 0.75)
	GameSettingsService.set_value("mouse_sensitivity", NAN)
	assert_eq(GameSettingsService.value("mouse_sensitivity"), 1.0)
	assert_null(InputBindingCodec.decode({"type": "button", "button": 999}))
	assert_null(InputBindingCodec.decode({"type": "key", "physical": []}))
	GameSettingsService.set_value("mouse_sensitivity", {})
	assert_eq(GameSettingsService.value("mouse_sensitivity"), 1.0)


func test_actual_keys_pad_and_axes_use_individual_outline_sprites() -> void:
	var key: Texture2D = InputPromptService.texture_for(_key(KEY_E))
	assert_eq(key.resource_path, "res://resources/kenney/kenney_input_prompts/keyboard_mouse/Default/keyboard_e_outline.png")
	assert_false(key is AtlasTexture)
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	var pad: Texture2D = InputPromptService.texture_for(button, "playstation_series")
	assert_eq(pad.resource_path, "res://resources/kenney/kenney_input_prompts/playstation_series/Default/playstation_button_cross_outline.png")

	var left: Texture2D = InputPromptService.texture_for(_axis(JOY_AXIS_RIGHT_X, -1), "xbox_series")
	var right: Texture2D = InputPromptService.texture_for(_axis(JOY_AXIS_RIGHT_X, 1), "xbox_series")
	assert_true(left.resource_path.ends_with("/xbox_stick_r_left.png"))
	assert_true(right.resource_path.ends_with("/xbox_stick_r_right.png"))
	assert_ne(left.resource_path, right.resource_path, "Directions load distinct complete sprites")
	button.button_index = JOY_BUTTON_MISC1
	assert_true(InputPromptService.texture_for(button, "xbox_series").resource_path.ends_with("/controller_xboxseries.png"), "Unsupported button uses device icon")
	assert_null(InputPromptCatalog.texture("unknown", "keyboard_e"))
	assert_null(InputPromptCatalog.texture("keyboard_mouse", "missing_button"))


func test_supported_device_families_use_face_and_direction_sprites() -> void:
	var prefixes: Dictionary[String, String] = {"xbox_series": "xbox", "playstation_series": "playstation", "steam_deck": "steamdeck", "steam_controller": "steam"}
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	for family: String in prefixes:
		var prefix: String = prefixes[family]
		button.button_index = JOY_BUTTON_A
		var face: Texture2D = InputPromptService.texture_for(button, family)
		var face_name: String = "button_cross" if family == "playstation_series" else "button_a"
		assert_true(face.resource_path.ends_with("/" + prefix + "_" + face_name + "_outline.png"), family + " face button")
		button.button_index = JOY_BUTTON_DPAD_UP
		var dpad: Texture2D = InputPromptService.texture_for(button, family)
		assert_true(dpad.resource_path.ends_with("/" + prefix + "_dpad_up_outline.png"), family + " dpad up")
		var stick: Texture2D = InputPromptService.texture_for(_axis(JOY_AXIS_LEFT_Y, -1), family)
		var stick_name: String = "stick_up" if family == "steam_controller" else "stick_l_up"
		assert_true(stick.resource_path.ends_with("/" + prefix + "_" + stick_name + ".png"), family + " negative vertical axis")


func test_prompt_tokens_render_icons_and_plain_caption() -> void:
	var label: InputPromptLabel = InputPromptLabel.new()
	add_child_autofree(label)
	label.set_prompt("%s Взять" % InputPromptService.token(&"interact"))
	assert_true(label.get_parsed_text().contains("Взять"))
	assert_false(label.get_parsed_text().contains("input="))
	assert_false(label.get_parsed_text().contains("[E]"))


func test_menu_restores_pause_mouse_and_existing_carry_capture() -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	var world: World = World.new()
	root.add_child(world)
	ECS.world = world
	var actor: Entity = Entity.new()
	actor.component_resources = [C_GrabControl.new()]
	root.add_child(actor)
	world.add_entity(actor, null, false)

	var token: int = InteractionControlFocus.acquire(actor, root, InteractionControlFocus.Priority.CARRY)
	var menu: SettingsMenu = SettingsMenu.new()
	menu.setup(actor, TEST_PATH)
	root.add_child(menu)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var before_mode: Input.MouseMode = Input.mouse_mode
	assert_true(menu.open_menu())
	assert_true(get_tree().paused)
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	assert_eq(InteractionControlFocus.current(actor), InteractionControlFocus.Priority.MODAL)
	menu.close_menu()
	assert_false(get_tree().paused)
	assert_eq(Input.mouse_mode, before_mode, "Restores the engine-reported mode (headless may reject capture)")
	assert_eq(InteractionControlFocus.current(actor), InteractionControlFocus.Priority.CARRY)
	InteractionControlFocus.release(actor, token)
	world.purge(false)
	root.free()


func test_sprint_mode_and_modifier_key_binding_round_trip() -> void:
	GameSettingsService.set_value("sprint_toggle", true)
	var shift: InputEventKey = _key(KEY_SHIFT)
	shift.shift_pressed = true
	assert_true(GameSettingsService.rebind(&"sprint", shift, true))
	var icons: Array[Texture2D] = InputPromptService.textures(&"sprint", 0)
	assert_eq(icons.size(), 1, "Сама Shift не рисует двойной модификатор")
	assert_eq(GameSettingsService.save(TEST_PATH), OK)
	GameSettingsService.set_value("sprint_toggle", false)
	GameSettingsService.load_settings(TEST_PATH)
	assert_true(bool(GameSettingsService.value("sprint_toggle")))
	assert_true(InputMap.action_has_event(&"sprint", _key(KEY_SHIFT)))
