@tool
extends Entity
class_name E_Terminal

@onready var _panel: TerminalPanel = $TerminalPanel


func open_for(actor: Entity) -> void:
	_panel.open_for(actor)


func close_panel() -> void:
	_panel.close_panel()


func is_panel_open() -> bool:
	return _panel.visible
