extends GutTest
## Actual addon registry, long-output scrollbar and project mouse/focus integration.

var _commands: DeveloperConsoleCommands
var _original_help: Console.ConsoleCommand
var _mouse: Input.MouseMode


func before_each() -> void:
	if bool(Console.is_visible()): Console.toggle_console()
	_mouse = Input.mouse_mode
	_original_help = Console.console_commands["help"]
	_commands = DeveloperConsoleCommands.new()
	add_child(_commands)
	Console.clear()


func after_each() -> void:
	if bool(Console.is_visible()): Console.toggle_console()
	_commands.free()
	Console.remove_command("qa_help_late")
	Console.remove_command("qa_help_hidden")
	Input.mouse_mode = _mouse
	Console.clear()


func test_help_uses_registered_syntax_and_preserves_builtin_and_alias() -> void:
	Console.console_commands["help"].function.call("apply_damage")
	var output: String = Console.rich_label.get_parsed_text()
	assert_true(output.contains("apply_damage <target> <amount> [damage_type]"))
	assert_true(output.contains("apply_damage target 10 melee"))
	Console.clear()
	Console.console_commands["debug_help"].function.call("packages")
	assert_true(Console.rich_label.get_parsed_text().contains("pkg_spawn"))
	Console.clear()
	Console.console_commands["help"].function.call()
	assert_true(Console.rich_label.get_parsed_text().contains("PageUp"), "Built-in instructions retained")
	assert_true(Console.rich_label.get_parsed_text().contains("Project groups:"))
	Console.clear()
	Console.console_commands["help"].function.call("nonexistent")
	assert_true(Console.rich_label.get_parsed_text().contains("Unknown subject"))
	_commands.free()
	assert_same(Console.console_commands["help"], _original_help)
	_commands = DeveloperConsoleCommands.new()
	add_child(_commands)


func test_plain_help_lists_live_registry_including_late_commands_but_not_hidden() -> void:
	Console.add_command("qa_help_late", func(_value: String) -> void: pass, ["value"], 1, "Late registered help probe")
	Console.add_hidden_command("qa_help_hidden", func() -> void: pass)
	Console._on_text_entered("help")
	var output: String = Console.rich_label.get_parsed_text()
	for command_name: String in Console.console_commands:
		var command: Console.ConsoleCommand = Console.console_commands[command_name]
		if not command.hidden:
			assert_true(output.contains(command_name), "Plain help includes " + command_name)
	assert_true(output.contains("Late registered help probe"), "Registry descriptions are discoverable")
	assert_true(output.contains("<value>"), "Required argument syntax is included")
	assert_false(output.contains("qa_help_hidden"), "Internal commands remain hidden")
	Console.clear()
	Console._on_text_entered("debug_help")
	assert_true(Console.rich_label.get_parsed_text().contains("qa_help_late"), "Alias also enumerates the current registry")


func test_long_output_scrolls_with_mouse_and_preserves_command_input() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var before: Input.MouseMode = Input.mouse_mode
	Console.toggle_console()
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	assert_same(get_viewport().gui_get_focus_owner(), Console.line_edit)
	for index: int in 200:
		Console.print_line("Long output line %d" % index)
	await get_tree().process_frame
	await get_tree().process_frame

	var scroll: VScrollBar = Console.rich_label.get_v_scroll_bar()
	assert_gt(scroll.max_value, scroll.page, "Actual output exceeds viewport")
	scroll.value = scroll.max_value - scroll.page
	var bottom: float = scroll.value
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Console.rich_label.gui_input.emit(wheel)
	assert_lt(scroll.value, bottom)
	assert_same(get_viewport().gui_get_focus_owner(), Console.line_edit)
	Console._on_text_entered("echo scroll_input_ok")
	assert_true(Console.rich_label.get_parsed_text().contains("scroll_input_ok"))
	Console.toggle_console()
	assert_eq(Input.mouse_mode, before)
