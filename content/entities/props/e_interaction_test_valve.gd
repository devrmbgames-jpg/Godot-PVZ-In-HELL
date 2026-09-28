extends Entity
## Scene-authored interaction trigger used to demonstrate R11.1 action/reset policies.
class_name E_InteractionTestValve

signal activated(active: bool)

var _active: bool = false


func activate() -> void:
	_active = not _active
	activated.emit(_active)


func is_active() -> bool:
	return _active
