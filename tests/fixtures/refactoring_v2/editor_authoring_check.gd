extends SceneTree
## Native dock selection and displayed identity regression; no rendered/gameplay acceptance.


#region Native editor tooling check
func _init() -> void:
	# Isolate native tooling from unrelated editor plugins, only in this test process.
	# No ProjectSettings.save call or on-disk plugin setting change is performed.
	ProjectSettings.set_setting("editor_plugins/enabled", PackedStringArray())
	_check.call_deferred()


func _check() -> void:
	# Let the normal EditorNode and configured plugins finish their initial lifecycle first.
	for frame: int in 10:
		await process_frame
	EditorInterface.open_scene_from_path("res://tests/fixtures/refactoring_v2/authoring_level.tscn")
	await process_frame
	if OS.get_cmdline_user_args().has("--baseline"):
		print("Entity authoring editor baseline: complete")
		quit()
		return
	var installer_script: GDScript = load(
		"res://content/editor/entity_authoring/install_entity_authoring.gd"
	) as GDScript
	var installer: EditorScript = installer_script.new() as EditorScript
	installer.call("_run")
	installer.call("_run")
	var editor_root: Control = EditorInterface.get_base_control()
	var plugin: EditorPlugin = editor_root.get_node("ProjectEntityAuthoring") as EditorPlugin
	var panel: VBoxContainer = plugin.get("_panel") as VBoxContainer
	var level: Node = EditorInterface.get_edited_scene_root()
	var actor: Node = level.get_node("Resident")
	var selection: EditorSelection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(actor)
	plugin.call("refresh_authoring")
	var level_label: Label = panel.get_node("%LevelId") as Label
	var instance_label: Label = panel.get_node("%InstanceId") as Label
	var level_valid: bool = (
		level != null and level.get_class() == "Node3D"
		and (plugin.get("_dock") as EditorDock).title == "Entity Authoring"
	)
	var previous_level_id: StringName = level.get_meta(&"persistent_world_id")
	(panel.get_node("%RepairLevel") as Button).pressed.emit()
	var assigned_level_id: StringName = level.get_meta(&"persistent_world_id")
	var undo_manager: EditorUndoRedoManager = plugin.get_undo_redo()
	var level_history: UndoRedo = undo_manager.get_history_undo_redo(
		undo_manager.get_object_history_id(level)
	)
	level_valid = level_valid and assigned_level_id != previous_level_id
	level_valid = level_valid and level_label.text == "Level ID: " + String(assigned_level_id)
	level_history.undo()
	level_valid = level_valid and level.get_meta(&"persistent_world_id") == previous_level_id
	level_valid = level_valid and level_label.text == "Level ID: " + String(previous_level_id)
	level_history.redo()
	level_valid = level_valid and level.get_meta(&"persistent_world_id") == assigned_level_id
	level_valid = level_valid and level_label.text == "Level ID: " + String(assigned_level_id)
	selection.clear()
	selection.add_node(level.get_node("Trader"))
	plugin.call("refresh_authoring")
	level_valid = level_valid and level_label.text == "Level ID: " + String(assigned_level_id)
	level_history.undo()
	level_valid = level_valid and level_label.text == "Level ID: " + String(previous_level_id)
	level_history.clear_history()
	print(
		"Entity authoring dock Level ID display/repair/undo/redo/selection: %s"
		% ("PASS" if level_valid else "FAIL")
	)
	selection.clear()
	selection.add_node(actor)
	plugin.call("refresh_authoring")
	var previous_instance_id: StringName = actor.get_meta(&"persistent_local_id")
	(panel.get_node("%RepairInstance") as Button).pressed.emit()
	var token: String = String(actor.get_meta(&"persistent_local_id", ""))
	var history: UndoRedo = undo_manager.get_history_undo_redo(
		undo_manager.get_object_history_id(actor)
	)
	var valid: bool = level_valid and token.is_valid_identifier() and token.begins_with("actor_")
	valid = valid and instance_label.text == "Instance ID: " + token
	history.undo()
	valid = valid and actor.get_meta(&"persistent_local_id") == previous_instance_id
	valid = valid and instance_label.text == "Instance ID: " + String(previous_instance_id)
	history.redo()
	valid = valid and String(actor.get_meta(&"persistent_local_id")) == token
	valid = valid and instance_label.text == "Instance ID: " + token
	history.undo()
	history.clear_history()
	var base_inspected: Object = EditorInterface.get_inspector().get_edited_object()
	(panel.get_node("%Configure") as Button).pressed.emit()
	valid = valid and EditorInterface.get_inspector().get_edited_object() == base_inspected
	var resource_inspector: EditorInspector = (
		panel.get_node("%ResourceInspector") as EditorInspector
	)
	var inspected_resource: Resource = resource_inspector.get_edited_object() as Resource
	valid = (
		valid and inspected_resource != null
		and inspected_resource.get_script().resource_path
		== "res://content/shared/authoring/entity_authoring.gd"
	)
	selection.clear()
	plugin.free()
	valid = valid and editor_root.get_node_or_null("ProjectEntityAuthoring") == null
	print("Entity authoring editor install/repair/undo/redo: %s" % ("PASS" if valid else "FAIL"))
	quit(0 if valid else 1)
#endregion
