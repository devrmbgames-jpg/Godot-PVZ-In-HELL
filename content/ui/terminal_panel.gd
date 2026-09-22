extends CanvasLayer
class_name TerminalPanel

const REFRESH_SECONDS: float = 0.2

@onready var title: Label = $Root/Panel/Margin/Rows/Title
@onready var registry: RichTextLabel = $Root/Panel/Margin/Rows/Registry
@onready var close_button: Button = $Root/Panel/Margin/Rows/Close
var _reader: Entity = null
var _capture_token: int = 0
var _refresh_remaining: float = 0.0
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


#region Lifecycle
func _ready() -> void:
	visible = false
	close_button.pressed.connect(close_panel)


func _exit_tree() -> void:
	close_panel()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"menu")):
		close_panel()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_reader) or not S_Grab.holder_available(_reader):
		close_panel()
		return
	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh()
		_refresh_remaining = REFRESH_SECONDS
#endregion


#region Public UI API
func open_for(actor: Entity) -> void:
	if visible:
		return
	_reader = actor
	_capture_token = InteractionFocus.acquire(actor, self, InteractionFocus.Priority.MODAL)
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_refresh()
	close_button.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	visible = false
	InteractionFocus.release(_reader, _capture_token)
	_capture_token = 0
	_reader = null
	Input.mouse_mode = _previous_mouse_mode
#endregion


func _refresh() -> void:
	var cycle: C_DayCycle = S_DayPhase.current()
	if cycle != null:
		title.text = "РЕЕСТР ПОСЫЛОК · ЦИКЛ %d" % cycle.day_index
		registry.text = PackageRegistrationService.terminal_text(cycle.day_index)
