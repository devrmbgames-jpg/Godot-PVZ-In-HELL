extends Node
## Installs the native read-only panel inside the existing console's input/focus lifetime.

const PANEL: PackedScene = preload("res://content/debug/gameplay_debugger_view.tscn")
const COMMAND: String = "debug_inspect"
const _THEME: Theme = preload("res://content/debug/theme_developer_console.tres")
const _FONT_SIZE: int = 14

var _view: GameplayDebuggerView
var _previous_theme: Theme
var _previous_input_menu_theme: Theme
var _previous_output_menu_theme: Theme
var _previous_font_size: int
var _previous_output_ratio: float


#region Console adapter lifecycle
func _ready() -> void:
	_previous_theme = Console.v_box_container.theme
	_previous_input_menu_theme = Console.line_edit.get_menu().theme
	_previous_output_menu_theme = Console.rich_label.get_menu().theme
	_previous_font_size = Console.font_size
	_previous_output_ratio = Console.panel.size_flags_stretch_ratio
	Console.v_box_container.theme = _THEME
	Console.line_edit.get_menu().theme = _THEME
	Console.rich_label.get_menu().theme = _THEME
	Console.font_size = _FONT_SIZE
	Console.panel.size_flags_stretch_ratio = 1.0
	_view = PANEL.instantiate() as GameplayDebuggerView
	Console.v_box_container.add_child(_view)
	Console.v_box_container.move_child(_view, 0)
	Console.add_command(
		COMMAND,
		_inspect,
		["target"],
		0,
		"Read selected Entity state. Includes dormant entity:<id>; refresh is explicit.",
	)
	Console.add_command_autocomplete_list(COMMAND, PackedStringArray(["self", "target"]))


func _exit_tree() -> void:
	Console.remove_command(COMMAND)
	_view.free()
	Console.v_box_container.theme = _previous_theme
	Console.line_edit.get_menu().theme = _previous_input_menu_theme
	Console.rich_label.get_menu().theme = _previous_output_menu_theme
	Console.font_size = _previous_font_size
	Console.panel.size_flags_stretch_ratio = _previous_output_ratio


func _inspect(raw_target: String = "target") -> void:
	_view.inspect(raw_target)
#endregion
