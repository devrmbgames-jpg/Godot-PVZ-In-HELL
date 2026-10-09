@tool
extends EditorPlugin
## Installs Inspector tooling; gameplay providers only run in detached headless preview.

const _INSPECTOR: Script = preload(
	"res://content/editor/entity_authoring/entity_authoring_inspector.gd"
)
var _inspector: EditorInspectorPlugin = null


#region Editor lifetime
func _enter_tree() -> void:
	_inspector = _INSPECTOR.new()
	_inspector.set("host_plugin", self)
	add_inspector_plugin(_inspector)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)
	_inspector = null
#endregion
