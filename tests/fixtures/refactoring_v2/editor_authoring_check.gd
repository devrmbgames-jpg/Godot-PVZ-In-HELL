extends SceneTree
## Native Inspector automation; does not assert visual usability or run gameplay.

const _PLUGIN_NAME: String = "project_entity_traits"
const _PROPERTY_PATH: String = "res://content/editor/entity_authoring/entity_traits_property.gd"
const _PLUGIN_PATH: String = "res://addons/project_entity_traits/plugin.gd"
var _failures: PackedStringArray = PackedStringArray()
var _configured_on_disk: bool = false


#region Headless editor acceptance
func _init() -> void:
	var configured: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled")
	_configured_on_disk = configured.has("res://addons/project_entity_traits/plugin.cfg")
	ProjectSettings.set_setting(
		"editor_plugins/enabled",
		PackedStringArray(["res://addons/project_entity_traits/plugin.cfg"]),
	)
	_check.call_deferred()


func _check() -> void:
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	for frame: int in 1800:
		if not filesystem.is_scanning():
			break
		await process_frame
	await _settle()
	if not EditorInterface.is_plugin_enabled(_PLUGIN_NAME):
		EditorInterface.set_plugin_enabled(_PLUGIN_NAME, true)
	await _settle()
	var editor_root: Node = root
	var plugin: EditorPlugin = _script_node(editor_root, _PLUGIN_PATH) as EditorPlugin
	_expect(_configured_on_disk, "Plugin configuration persists between editor processes")
	_expect(plugin != null, "Persistent plugin restores at editor startup")
	if plugin == null:
		_finish()
		return
	EditorInterface.open_scene_from_path("res://tests/fixtures/refactoring_v2/authoring_level.tscn")
	await _settle()
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var actor: Node = scene_root.get_node("Box")
	EditorInterface.inspect_object(actor)
	await _settle()
	var property_node: Node = _script_node(EditorInterface.get_inspector(), _PROPERTY_PATH)
	var property: EditorProperty = property_node as EditorProperty
	_expect(property != null, "Traits replace only the native traits property")
	if property == null:
		_finish()
		return
	var original: Array = (actor.get("traits") as Array).duplicate()
	var manager: EditorUndoRedoManager = plugin.get_undo_redo()
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(actor))
	property.call("_add_new")
	await _settle()
	_expect((actor.get("traits") as Array).size() == original.size() + 1, "New Trait")
	history.undo()
	await _settle()
	_expect(actor.get("traits") == original, "Native Inspector undo")
	history.redo()
	await _settle()
	_expect((actor.get("traits") as Array).size() == original.size() + 1, "Native Inspector redo")
	EditorInterface.inspect_object(actor)
	await _settle()
	property = _script_node(EditorInterface.get_inspector(), _PROPERTY_PATH) as EditorProperty
	property.call("_move", original.size(), -1)
	await _settle()
	_expect((actor.get("traits") as Array)[0].trait_id == &"new_trait", "Reorder")
	property.call("_assign", original[0], 0)
	await _settle()
	_expect((actor.get("traits") as Array)[0] == original[0], "Native resource assignment")
	property.call("_remove", 0)
	await _settle()
	_expect((actor.get("traits") as Array).size() == original.size(), "Remove")
	var before_invalid: Array = (actor.get("traits") as Array).duplicate()
	property.call(
		"_add_existing",
		"res://content/domains/combat/definitions/def_impact_default.tres",
	)
	_expect(actor.get("traits") == before_invalid, "Add rejects a resource of another type")
	property.call("_add_existing", "res://content/domains/combat/authoring/et_impact_capture.tres")
	await _settle()
	_expect((actor.get("traits") as Array).size() == original.size() + 1, "Add existing Trait")
	property.call("_remove", 1)
	await _settle()
	property.call("_make_unique", 0)
	await _settle()
	var local_trait: Resource = (actor.get("traits") as Array)[0] as Resource
	_expect(local_trait != original[0], "Make Unique creates a local copy")
	local_trait.set("trait_id", &"local_impact")
	_expect(original[0].trait_id == &"physical_impact", "Local settings preserve shared resource")
	EditorInterface.inspect_object(actor)
	await _settle()
	property = _script_node(EditorInterface.get_inspector(), _PROPERTY_PATH) as EditorProperty
	property.call("_inspect", original[0], true, 0)
	_expect(
		EditorInterface.get_inspector().get_edited_object() == actor,
		"Shared external Trait remains protected",
	)
	var packed: PackedScene = PackedScene.new()
	_expect(packed.pack(scene_root) == OK, "Native pack of edited nested prefab")
	var scene_path: String = "res://".path_join(".artifacts/direct_traits/editor_saved.tscn")
	_expect(
		ResourceSaver.save(packed, scene_path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS) == OK,
		"Save edited scene with native built-in resource paths",
	)
	EditorInterface.open_scene_from_path(scene_path)
	await _settle()
	var reopened_root: Node = EditorInterface.get_edited_scene_root()
	var reopened_actor: Node = reopened_root.get_node("Box")
	EditorInterface.inspect_object(reopened_actor)
	await _settle()
	property = _script_node(EditorInterface.get_inspector(), _PROPERTY_PATH) as EditorProperty
	var saved_trait: Resource = (reopened_actor.get("traits") as Array)[0] as Resource
	_expect(saved_trait.get("trait_id") == &"local_impact", "Save/reopen local Trait settings")
	var reopened_history: UndoRedo = manager.get_history_undo_redo(
		manager.get_object_history_id(reopened_actor)
	)
	var undo_version: int = reopened_history.get_version()
	property.call("_inspect", saved_trait, true, 0)
	await _settle()
	_expect(
		EditorInterface.get_inspector().get_edited_object() == saved_trait,
		"Reopened local Trait settings use the existing resource",
	)
	_expect(
		reopened_history.get_version() == undo_version,
		"Opening settings creates no unique copy or undo action",
	)
	_expect(original[0].trait_id == &"physical_impact", "Reopened settings preserve shared Trait")
	var saved_scene: PackedScene = load(scene_path) as PackedScene
	var saved_state: SceneState = saved_scene.get_state()
	var builtin_trait: Resource
	for node_index: int in saved_state.get_node_count():
		if saved_state.get_node_name(node_index) != &"Box":
			continue
		for property_index: int in saved_state.get_node_property_count(node_index):
			if saved_state.get_node_property_name(node_index, property_index) == &"traits":
				var saved_traits: Array = saved_state.get_node_property_value(
					node_index, property_index,
				)
				builtin_trait = saved_traits[0] as Resource
	_expect(
		builtin_trait != null and builtin_trait.resource_path.contains("::"),
		"Saved SceneState retains the built-in Trait path",
	)
	EditorInterface.inspect_object(reopened_actor)
	await _settle()
	property = _script_node(EditorInterface.get_inspector(), _PROPERTY_PATH) as EditorProperty
	property.call("_inspect", builtin_trait, true, 0)
	await _settle()
	_expect(
		EditorInterface.get_inspector().get_edited_object() == builtin_trait,
		"Saved built-in Trait settings open without another copy",
	)
	_expect(
		(reopened_actor.get("traits") as Array)[0] == saved_trait
		and reopened_history.get_version() == undo_version,
		"Opening saved built-in settings preserves the Entity array and undo history",
	)
	EditorInterface.open_scene_from_path("res://tests/fixtures/refactoring_v2/authoring_level.tscn")
	await _settle()
	EditorInterface.inspect_object(actor)
	await _settle()
	history.undo()
	await _settle()
	_expect((actor.get("traits") as Array)[0] == original[0], "Make Unique undo")
	while history.has_undo():
		history.undo()
	history.clear_history()
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, false)
	await _settle()
	EditorInterface.inspect_object(actor)
	await _settle()
	_expect(
		_script_node(EditorInterface.get_inspector(), _PROPERTY_PATH) == null,
		"Disable restores the standard Inspector",
	)
	var has_native_traits: bool = false
	for descriptor: Dictionary in actor.get_property_list():
		if descriptor.name == "traits":
			has_native_traits = bool(int(descriptor.usage) & PROPERTY_USAGE_EDITOR)
	_expect(has_native_traits, "Exported native traits fallback")
	EditorInterface.set_plugin_enabled(_PLUGIN_NAME, true)
	await _settle()
	_expect(_script_node(editor_root, _PLUGIN_PATH) != null, "Plugin enable/disable/enable")
	_finish()


func _script_node(node: Node, script_path: String) -> Node:
	var script: Script = node.get_script() as Script
	if script != null and script.resource_path == script_path:
		return node
	for child: Node in node.get_children(true):
		var found: Node = _script_node(child, script_path)
		if found != null:
			return found
	return null


func _settle() -> void:
	for frame: int in 6:
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
	print("Inspector: %s: %s" % ["PASS" if condition else "FAIL", message])


func _finish() -> void:
	print("Direct Traits editor: %s" % ("PASS" if _failures.is_empty() else str(_failures)))
	quit(0 if _failures.is_empty() else 1)
#endregion
