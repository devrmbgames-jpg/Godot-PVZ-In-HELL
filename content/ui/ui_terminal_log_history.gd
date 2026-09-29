# Лог с историей всяких штук
# TODO функционал надо доделать
extends PanelContainer
class_name UI_TerminalLogHistory

## Тайтл окна
@onready var _label_title: Label = %LabelTitle
## Текст с неким логом
@onready var _rich_text_label: RichTextLabel = %RichTextLabel
## Поиск по некому логу
@onready var _line_edit_find: LineEdit = %LineEditFind
