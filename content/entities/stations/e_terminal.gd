@tool
extends Entity
## Сценовый вход в TerminalPanel; захват управления и данные журнала принадлежат панели/сервисам.
class_name E_Terminal

@onready var _panel: TerminalPanel = $TerminalPanel


## Передаёт панели запрос открытия для действующего участника.
func open_for(actor: Entity) -> void:
	_panel.open_for(actor)


## Закрывает панель через её штатное освобождение управления.
func close_panel() -> void:
	_panel.close_panel()


## Фактическая видимость панели терминала.
func is_panel_open() -> bool:
	return _panel.visible
