# Универсальная текстовая история с локальным поиском.
extends PanelContainer
class_name UI_TerminalLogHistory

@onready var _label_title: Label = %LabelTitle
@onready var _rich_text_label: RichTextLabel = %RichTextLabel
@onready var _line_edit_find: LineEdit = %LineEditFind

var _entries: PackedStringArray = []


func _ready() -> void:
	_line_edit_find.text_changed.connect(_on_filter_changed)


func present(title: String, entries: PackedStringArray) -> void:
	_label_title.text = title
	_entries = entries
	_apply_filter(_line_edit_find.text)


func clear_log(title: String) -> void:
	_label_title.text = title
	_entries = []
	_rich_text_label.text = ""


func _on_filter_changed(value: String) -> void:
	_apply_filter(value)


func _apply_filter(value: String) -> void:
	var needle: String = value.strip_edges().to_lower()
	if needle.is_empty():
		_rich_text_label.text = "\n\n".join(_entries)
		return
	var filtered: PackedStringArray = []
	for entry: String in _entries:
		if needle in entry.to_lower():
			filtered.append(entry)
	_rich_text_label.text = "\n\n".join(filtered)
