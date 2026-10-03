extends CanvasLayer
## Project-owned DialogueManager presentation. It owns modal input only, never gameplay facts.
class_name CustomerDialoguePanel

const PANEL_MIN_WIDTH: float = 720.0
const PANEL_MIN_HEIGHT: float = 220.0
const ROOT_MARGIN: float = 32.0
const ACTIVE_GROUP: StringName = &"customer_dialogue_panel"

var _actor: Entity = null
var _context: CustomerDialogueContext = null
var _resource: DialogueResource = null
var _line: DialogueLine = null
var _capture_token: int = 0
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _input_enabled: bool = false
var _closed: bool = false

var _speaker: Label = null
var _text: RichTextLabel = null
var _responses: VBoxContainer = null
var _continue_button: Button = null
var _close_button: Button = null


func _ready() -> void:
	add_to_group(ACTIVE_GROUP)
	layer = 90
	_build_ui()


func _exit_tree() -> void:
	_close_internal(false)


func _process(_delta: float) -> void:
	var continue_icons: Array[Texture2D] = InputPromptService.textures(&"interact")
	_continue_button.icon = continue_icons[0] if not continue_icons.is_empty() else null
	var close_icons: Array[Texture2D] = InputPromptService.textures(&"menu")
	_close_button.icon = close_icons[0] if not close_icons.is_empty() else null
	if _closed:
		return
	if (
		not is_instance_valid(_actor)
		or not GrabService.holder_available(_actor)
		or _context == null
		or not _context.can_continue()
	):
		close_dialogue()
	elif _line != null:
		_text.text = _context.perceived_text(_line.text)


func _unhandled_input(event: InputEvent) -> void:
	if _closed or not _input_enabled:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"menu"):
		close_dialogue()
	elif (
		_line != null
		and _line.responses.is_empty()
		and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"))
	):
		_advance(_line.next_id)


func open_for(
	actor: Entity,
	context: CustomerDialogueContext,
	resource: DialogueResource,
	cue: String,
) -> bool:
	if _closed or _capture_token != 0:
		return false
	_actor = actor
	_context = context
	_resource = resource
	_capture_token = InteractionControlFocus.acquire(
		actor,
		self,
		InteractionControlFocus.Priority.MODAL,
	)
	if _capture_token == 0:
		return false
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_input_enabled = false
	call_deferred("_enable_input")
	_advance(cue)
	return true


func close_dialogue() -> void:
	_close_internal(true)
	if not is_queued_for_deletion():
		queue_free()


func _enable_input() -> void:
	_input_enabled = true


func _advance(next_id: String) -> void:
	if _closed or _resource == null or _context == null:
		return
	var resource: DialogueResource = _resource
	_line = await resource.get_next_dialogue_line(next_id, [{ "ctx": _context }])
	if _closed:
		DialogueResourceLifecycle.release_runtime_references(resource)
		_line = null
		return
	if _line == null:
		close_dialogue()
		return
	_render_line()


func _render_line() -> void:
	_clear_responses()
	_speaker.text = _line.character
	_speaker.visible = not _line.character.is_empty()
	_text.text = _context.perceived_text(_line.text)
	_continue_button.visible = _line.responses.is_empty()
	_continue_button.disabled = false
	for response_value: Variant in _line.responses:
		var response: DialogueResponse = response_value as DialogueResponse
		if response == null or not response.is_allowed:
			continue
		var button: Button = Button.new()
		button.text = format_response_text(response.text, response.tags)
		button.pressed.connect(_on_response_pressed.bind(response))
		_responses.add_child(button)
	if _responses.get_child_count() > 0:
		var first: Button = _responses.get_child(0) as Button
		if first != null:
			first.grab_focus()
	else:
		_continue_button.grab_focus()


## Presentation only: keep the authored response and its routing tags untouched.
static func format_response_text(text: String, tags: PackedStringArray) -> String:
	var prefix: String = ""
	match CustomerDialogueIntent.from_tags(tags):
		CustomerDialogueIntent.Type.HONEST:
			prefix = "[честно]"
		CustomerDialogueIntent.Type.LIE:
			prefix = "[обман]"
		CustomerDialogueIntent.Type.PERSUADE:
			prefix = "[убедить]"
		CustomerDialogueIntent.Type.THREAT:
			prefix = "[угроза]"
		CustomerDialogueIntent.Type.FLIRT:
			prefix = "[флирт]"
		CustomerDialogueIntent.Type.JOKE:
			prefix = "[шутка]"
	if prefix.is_empty() or text == prefix or text.begins_with(prefix + " "):
		return text
	return prefix + " " + text


func _on_response_pressed(response: DialogueResponse) -> void:
	if response == null:
		return
	_context.apply_response_tags(response.tags)
	_advance(response.next_id)


func _on_continue_pressed() -> void:
	if _line != null and _line.responses.is_empty():
		_continue_button.disabled = true
		_advance(_line.next_id)


func _clear_responses() -> void:
	for child: Node in _responses.get_children():
		_responses.remove_child(child)
		child.queue_free()


func _close_internal(return_to_service: bool) -> void:
	if _closed:
		return
	_closed = true
	_input_enabled = false
	if _capture_token != 0 and is_instance_valid(_actor):
		InteractionControlFocus.release(_actor, _capture_token)
	_capture_token = 0
	if return_to_service and _context != null:
		_context.end()
	_actor = null
	_context = null
	DialogueResourceLifecycle.release_runtime_references(_resource)
	_resource = null
	_line = null
	Input.mouse_mode = _previous_mouse_mode


func _build_ui() -> void:
	var root: MarginContainer = MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", int(ROOT_MARGIN))
	root.add_theme_constant_override("margin_top", int(ROOT_MARGIN))
	root.add_theme_constant_override("margin_right", int(ROOT_MARGIN))
	root.add_theme_constant_override("margin_bottom", int(ROOT_MARGIN))
	add_child(root)

	var align: VBoxContainer = VBoxContainer.new()
	align.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(align)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_MIN_WIDTH, PANEL_MIN_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	align.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 20)
	rows.add_child(_speaker)

	_text = RichTextLabel.new()
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size.y = 70.0
	_text.add_theme_font_size_override("normal_font_size", 18)
	rows.add_child(_text)

	_responses = VBoxContainer.new()
	_responses.add_theme_constant_override("separation", 6)
	rows.add_child(_responses)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	rows.add_child(buttons)

	_continue_button = Button.new()
	_continue_button.text = "Продолжить"
	_continue_button.pressed.connect(_on_continue_pressed)
	buttons.add_child(_continue_button)

	_close_button = Button.new()
	_close_button.text = "Закрыть"
	_close_button.pressed.connect(close_dialogue)
	buttons.add_child(_close_button)
