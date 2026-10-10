extends VBoxContainer
## Read-only console panel; owns only a weak selection and explicit detached refreshes.
class_name GameplayDebuggerView

var _selection: WeakRef

@onready var _target: LineEdit = %Target
@onready var _tree: Tree = %State
@onready var _status: Label = %Status
@onready var _select_button: Button = %Select
@onready var _refresh_button: Button = %Refresh
@onready var _close_button: Button = %Close


#region Panel lifecycle
func _ready() -> void:
	_tree.set_column_title(0, "State / owner")
	_tree.set_column_title(1, "Snapshot value")
	_select_button.pressed.connect(_select_entered)
	_refresh_button.pressed.connect(refresh)
	_close_button.pressed.connect(close)
	_target.text_submitted.connect(_select_submitted)
	Console.console_closed.connect(close)
	hide()


func _exit_tree() -> void:
	Console.console_closed.disconnect(close)


## Selects a registered actor without changing gameplay focus, participation or AI state.
func inspect(raw_target: String = "target") -> void:
	_target.text = raw_target
	var actor: Entity = GameplayDebuggerData.resolve(raw_target)
	_selection = weakref(actor) if actor != null else null
	show()
	refresh()


## Captures on demand only; no frame polling or persistent gameplay mirror.
func refresh() -> void:
	var candidate: Variant = _selection.get_ref() if _selection != null else null
	var state: Dictionary[String, Variant] = GameplayDebuggerData.snapshot(candidate)
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	for field: String in state:
		_append(root, field, state[field])
	_status.text = "Read-only snapshot / " + String(state["status"])


## Releases the presentation selection when the console closes or the panel is dismissed.
func close() -> void:
	_selection = null
	_tree.clear()
	hide()
	if bool(Console.is_visible()):
		Console.line_edit.grab_focus()
#endregion


#region Native tree rows
func _select_entered() -> void:
	inspect(_target.text)


func _select_submitted(_text: String) -> void:
	_select_entered()


func _append(parent: TreeItem, key: String, value: Variant) -> void:
	var row: TreeItem = _tree.create_item(parent)
	row.set_text(0, key)
	if value is Dictionary:
		var fields: Dictionary = value as Dictionary
		for field: Variant in fields:
			_append(row, str(field), fields[field])
	elif value is Array or value is PackedStringArray:
		for index: int in value.size():
			_append(row, str(index), value[index])
		row.set_text(1, "%d entries" % value.size())
	else:
		row.set_text(1, str(value))
		row.set_tooltip_text(1, str(value))
#endregion
