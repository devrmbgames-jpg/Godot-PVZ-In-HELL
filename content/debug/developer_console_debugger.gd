extends Node
## Installs the native read-only panel inside the existing console's input/focus lifetime.

const PANEL: PackedScene = preload("res://content/debug/gameplay_debugger_view.tscn")
const COMMAND: String = "debug_inspect"

var _view: GameplayDebuggerView


#region Console adapter lifecycle
func _ready() -> void:
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


func _inspect(raw_target: String = "target") -> void:
	_view.inspect(raw_target)
#endregion
