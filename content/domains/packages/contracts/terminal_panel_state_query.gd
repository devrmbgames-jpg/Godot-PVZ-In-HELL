extends RefCounted
## Одноразовый synchronous ответ native panel owner о видимости терминала.
class_name TerminalPanelStateQuery

var _open: bool = false

#region Visibility response
## Записывает фактическую видимость в текущий запрос.
func record_open(visible: bool) -> void:
	_open = visible


## Возвращает сообщённую видимость без удержания панели.
func is_open() -> bool:
	return _open
#endregion
