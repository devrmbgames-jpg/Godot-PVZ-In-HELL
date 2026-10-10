@tool
extends E_TraitedEntity
## Native terminal request boundary; panel presentation and input capture belong to global UI.
class_name E_Terminal

## Запрашивает открытие авторской панели для участника.
signal panel_open_requested(actor: Entity)
## Запрашивает штатное закрытие авторской панели.
signal panel_close_requested
## Читает текущую видимость через ответ native panel owner.
signal panel_state_requested(query: TerminalPanelStateQuery)

#region Native panel requests
## Передаёт панели запрос открытия для действующего участника.
func open_for(actor: Entity) -> void:
	panel_open_requested.emit(actor)


## Запрашивает штатное освобождение управления панелью.
func close_panel() -> void:
	panel_close_requested.emit()


## Возвращает фактическую видимость, сообщённую владельцем панели.
func is_panel_open() -> bool:
	var query: TerminalPanelStateQuery = TerminalPanelStateQuery.new()
	panel_state_requested.emit(query)
	return query.is_open()
#endregion
