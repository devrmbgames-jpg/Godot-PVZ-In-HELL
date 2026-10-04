extends RefCounted
## Сессионное разрешение отладочного HUD; обычное игровое состояние не изменяет.
class_name DebugHudService

static var _enabled: bool = true


## Текущая сессионная настройка отладочного представления.
static func is_enabled() -> bool:
	return _enabled


## Меняет только разрешение отладочного HUD для текущего процесса.
static func set_enabled(enabled: bool) -> void:
	_enabled = enabled
