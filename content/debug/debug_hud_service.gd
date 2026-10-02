extends RefCounted
## Session presentation preference. Gameplay, ordinary feedback and console stay active.
class_name DebugHudService

static var _enabled: bool = true


static func is_enabled() -> bool:
	return _enabled


static func set_enabled(enabled: bool) -> void:
	_enabled = enabled
