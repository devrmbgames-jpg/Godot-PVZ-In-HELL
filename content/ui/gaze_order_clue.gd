@tool
extends Label3D
## Периодически показывает настенную подсказку без кеша живой Entity.

const REFRESH_SECONDS: float = 0.1

var _refresh_remaining: float = 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		text = ""
		_refresh()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_refresh_remaining -= delta
	if _refresh_remaining <= 0.0:
		_refresh_remaining = REFRESH_SECONDS
		_refresh()


func _refresh() -> void:
	text = GazeOrderCluePresentation.text_for(self)
	visible = not text.is_empty()
