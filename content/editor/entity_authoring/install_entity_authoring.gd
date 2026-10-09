@tool
extends EditorScript
## Run once per editor session to install Inspector tooling without editing addons.

const _PLUGIN_SCRIPT: Script = preload(
	"res://content/editor/entity_authoring/entity_authoring_plugin.gd"
)
const _PLUGIN_NODE: StringName = &"ProjectEntityAuthoring"


#region Explicit editor installation
func _run() -> void:
	var editor_root: Control = EditorInterface.get_base_control()
	if editor_root.get_node_or_null(NodePath(String(_PLUGIN_NODE))) != null:
		print("Entity Authoring is already installed for this editor session")
		return
	var plugin: EditorPlugin = _PLUGIN_SCRIPT.new() as EditorPlugin
	plugin.name = _PLUGIN_NODE
	editor_root.add_child(plugin)
	print("Entity Authoring installed: select an Entity and validate its scene composition")
#endregion
