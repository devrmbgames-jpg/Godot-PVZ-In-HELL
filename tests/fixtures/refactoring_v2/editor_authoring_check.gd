extends SceneTree
## Headless editor check of installation and native undo; no rendered/gameplay acceptance.


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
	var inspector: EditorInspectorPlugin = plugin.get("_inspector") as EditorInspectorPlugin
	var level: Node = EditorInterface.get_edited_scene_root()
	var level_valid: bool = level != null and level.get_class() == "Node3D"
	level_valid = level_valid and bool(inspector.call("_can_handle", level))
	level_valid = (
		level_valid
		and bool(
			inspector.call(
				"_parse_property",
				level,
				TYPE_STRING_NAME,
				"metadata/persistent_world_id",
				PROPERTY_HINT_NONE,
				"",
				PROPERTY_USAGE_DEFAULT,
				false,
			)
		)
	)
	var previous_level_id: StringName = level.get_meta(&"persistent_world_id")
	inspector.call("_repair_identity", weakref(level), &"persistent_world_id")
	var assigned_level_id: StringName = level.get_meta(&"persistent_world_id")
	var undo_manager: EditorUndoRedoManager = plugin.get_undo_redo()
	var level_history: UndoRedo = undo_manager.get_history_undo_redo(
		undo_manager.get_object_history_id(level)
	)
	level_valid = level_valid and assigned_level_id != previous_level_id
	level_history.undo()
	level_valid = level_valid and level.get_meta(&"persistent_world_id") == previous_level_id
	level_history.redo()
	level_valid = level_valid and level.get_meta(&"persistent_world_id") == assigned_level_id
	level_history.undo()
	level_history.clear_history()
	print(
		"Entity authoring level identity read-only/repair/undo/redo: %s"
		% ("PASS" if level_valid else "FAIL")
	)
	var actor: Node = Node.new()
	inspector.call("_repair_identity", weakref(actor), &"persistent_local_id")
	var token: String = String(actor.get_meta(&"persistent_local_id", ""))
	var history: UndoRedo = undo_manager.get_history_undo_redo(
		undo_manager.get_object_history_id(actor)
	)
	var valid: bool = level_valid and token.is_valid_identifier() and token.begins_with("actor_")
	history.undo()
	valid = valid and not actor.has_meta(&"persistent_local_id")
	history.redo()
	valid = valid and String(actor.get_meta(&"persistent_local_id")) == token
	history.clear_history()
	actor.free()
	plugin.free()
	print("Entity authoring editor install/repair/undo/redo: %s" % ("PASS" if valid else "FAIL"))
	quit(0 if valid else 1)
#endregion
