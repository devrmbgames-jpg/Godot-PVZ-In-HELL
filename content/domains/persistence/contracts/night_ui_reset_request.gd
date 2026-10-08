extends RefCounted
## Запрашивает синхронное закрытие native gameplay panels перед Night cleanup.
class_name NightUiResetRequest

## Канал global UI session cleanup.
const EVENT: StringName = &"night_ui_reset_requested"
## Lifetime witness корня текущего World; не хранит UI или ECS authority.
var root_reference: WeakRef

#region Request context
func _init(root: Node) -> void:
	root_reference = weakref(root)
#endregion
