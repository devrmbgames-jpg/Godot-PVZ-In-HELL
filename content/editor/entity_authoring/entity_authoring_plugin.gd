@tool
extends EditorPlugin
## Persistent Inspector integration plus a diagnostics/identity dock with no Trait editing.

const _PANEL: PackedScene = preload(
	"res://content/editor/entity_authoring/entity_authoring_dock.tscn"
)
var _dock: EditorDock
var _panel: VBoxContainer
var _inspector: EditorInspectorPlugin


#region Editor lifetime
func _enter_tree() -> void:
	_inspector = preload(
		"res://content/editor/entity_authoring/entity_traits_inspector.gd"
	).new() as EditorInspectorPlugin
	add_inspector_plugin(_inspector)
	_refresh_inspector()
	_dock = EditorDock.new()
	_dock.title = "Entity Authoring"
	_dock.layout_key = "ProjectEntityAuthoring"
	_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	_panel = _PANEL.instantiate() as VBoxContainer
	_panel.set("host_plugin", self)
	_dock.add_child(_panel)
	add_dock(_dock)
	EditorInterface.get_selection().selection_changed.connect(refresh_authoring)
	scene_changed.connect(_scene_changed)
	refresh_authoring()


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)
	_inspector = null
	_refresh_inspector()
	EditorInterface.get_selection().selection_changed.disconnect(refresh_authoring)
	scene_changed.disconnect(_scene_changed)
	remove_dock(_dock)
	_dock.free()
	_dock = null
	_panel = null


## Rebinds the separate authoring UI after an editor selection or scene switch.
func refresh_authoring() -> void:
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	var selection: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	var actor: Node = selection.back() if not selection.is_empty() else null
	if actor != edited_root and not actor is Entity:
		actor = null
	_panel.call("bind_actor", actor, edited_root)


func _scene_changed(_edited_root: Node) -> void:
	refresh_authoring()


func _refresh_inspector() -> void:
	var inspector: EditorInspector = EditorInterface.get_inspector()
	var inspected: Object = inspector.get_edited_object()
	if inspected != null:
		inspector.edit(null)
		inspector.edit(inspected)
#endregion
