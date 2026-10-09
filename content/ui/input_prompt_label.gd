extends RichTextLabel
## Текст и [input=action] tokens; подставляет отдельные PNG фактических кнопок активного устройства.
class_name InputPromptLabel

## -1 — активное устройство; 0/1 — колонка клавиатуры/геймпада в настройках.
@export_range(-1, 1) var binding_device: int = -1

var _prompt: String = ""
var _revision: int = -1
var _pattern: RegEx = RegEx.new()


#region Подготовка и ревизия
func _ready() -> void:
	_pattern.compile("\\[input=([a-z0-9_]+)\\]")
	bbcode_enabled = false
	fit_content = true
	scroll_active = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _revision != InputPromptService.revision():
		_render()


#endregion

#region Текст и иконки
## Устанавливает текст с [input=action]; одинаковый текст не пересобирается без смены ревизии.
func set_prompt(message: String) -> void:
	if message == _prompt and _revision == InputPromptService.revision():
		return

	_prompt = message
	_render()


func _render() -> void:
	if not is_node_ready():
		return

	_revision = InputPromptService.revision()
	clear()
	push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	var start: int = 0
	for match_entry: RegExMatch in _pattern.search_all(_prompt):
		add_text(_prompt.substr(start, match_entry.get_start() - start))
		var action: StringName = StringName(match_entry.get_string(1))
		var groups: Array[Array] = InputPromptService.groups(action, binding_device)
		for group_index: int in groups.size():
			if group_index > 0:
				add_text(" / ")
			var icons: Array = groups[group_index]
			for icon_index: int in icons.size():
				if icon_index > 0:
					add_text(" + ")
				add_image(icons[icon_index] as Texture2D, int(InputPromptService.SIZE.x), int(InputPromptService.SIZE.y))
		if groups.is_empty():
			add_text("—")
		start = match_entry.get_end()
	add_text(_prompt.substr(start))
	pop()

#endregion
