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
	var actor: Node = Node.new()
	inspector.call("_repair_identity", weakref(actor), &"persistent_local_id")
	var token: String = String(actor.get_meta(&"persistent_local_id", ""))
	var undo_manager: EditorUndoRedoManager = plugin.get_undo_redo()
	var history: UndoRedo = undo_manager.get_history_undo_redo(
		undo_manager.get_object_history_id(actor)
	)
	var valid: bool = token.is_valid_identifier() and token.begins_with("actor_")
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
