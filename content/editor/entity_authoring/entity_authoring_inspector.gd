@tool
extends EditorInspectorPlugin
## Simple authoring inputs and explicit diagnostics, without executing gameplay inside the editor.

const _AUTHORING_META: StringName = &"entity_composition"
const _LOCAL_ID_META: StringName = &"persistent_local_id"
const _WORLD_ID_META: StringName = &"persistent_world_id"
const _PREVIEW_RUNNER: String = "res://utils/preview_entity_authoring.gd"
const _PREVIEW_DIRECTORY: String = ".artifacts/authoring_preview"

## Editor owner supplies the native undo manager; this reference is released with the plugin.
var host_plugin: EditorPlugin = null
var _advanced: bool = false


#region Inspector presentation
func _can_handle(object: Object) -> bool:
	return object is Entity


func _parse_begin(object: Object) -> void:
	var actor: Node = object as Node
	var panel: VBoxContainer = VBoxContainer.new()
	var title: Label = Label.new()
	title.text = "Entity Authoring"
	panel.add_child(title)
	var identity: Label = Label.new()
	identity.text = "Instance ID: %s" % actor.get_meta(_LOCAL_ID_META, "unassigned")
	panel.add_child(identity)
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	var world_identity: Label = Label.new()
	world_identity.text = "Level ID: %s" % (
		edited_root.get_meta(_WORLD_ID_META, "prefab / unassigned")
		if edited_root != null
		else "no edited scene"
	)
	panel.add_child(world_identity)
	var authoring: EntityAuthoring = (
		actor.get_meta(_AUTHORING_META) as EntityAuthoring
		if actor.has_meta(_AUTHORING_META)
		else null
	)
	var resource_id: Label = Label.new()
	resource_id.text = "Template ID: %s" % (
		authoring.entity_template.key
		if authoring != null and authoring.entity_template != null
		else "scene intrinsic"
	)
	panel.add_child(resource_id)
	var repair: Button = Button.new()
	repair.text = "Create / Repair Instance ID"
	repair.pressed.connect(_repair_identity.bind(weakref(actor), _LOCAL_ID_META))
	panel.add_child(repair)
	if edited_root != null and not edited_root is Entity:
		var repair_level: Button = Button.new()
		repair_level.text = "Create / Repair Level ID"
		repair_level.pressed.connect(_repair_identity.bind(weakref(edited_root), _WORLD_ID_META))
		panel.add_child(repair_level)
	var configure: Button = Button.new()
	configure.text = "Template / Profiles / Named Bindings"
	configure.pressed.connect(_edit_authoring.bind(weakref(actor)))
	panel.add_child(configure)
	var validate: Button = Button.new()
	validate.text = "Validate Scene Composition"
	var diagnostics: RichTextLabel = RichTextLabel.new()
	diagnostics.fit_content = true
	diagnostics.custom_minimum_size.x = 180.0
	validate.pressed.connect(_validate_snapshot.bind(weakref(actor), weakref(diagnostics)))
	panel.add_child(validate)
	var advanced: CheckButton = CheckButton.new()
	advanced.text = "Advanced: Recipes and Provider Diagnostics"
	advanced.button_pressed = _advanced
	advanced.toggled.connect(_set_advanced.bind(weakref(actor)))
	panel.add_child(advanced)
	panel.add_child(diagnostics)
	add_custom_control(panel)


func _parse_property(
	_object: Object,
	_type: Variant.Type,
	property_name: String,
	_hint: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool,
) -> bool:
	if property_name in ["metadata/persistent_local_id", "metadata/persistent_world_id", "id"]:
		return true
	return not _advanced and property_name in ["component_resources", "serialize_config"]


func _set_advanced(enabled: bool, actor_ref: WeakRef) -> void:
	_advanced = enabled
	var actor: Node = actor_ref.get_ref() as Node
	if actor != null:
		actor.notify_property_list_changed()
#endregion


#region Explicit undoable identity operation
func _repair_identity(actor_ref: WeakRef, metadata_key: StringName) -> void:
	var actor: Node = actor_ref.get_ref() as Node
	if actor == null:
		return
	var previous: Variant = actor.get_meta(metadata_key) if actor.has_meta(metadata_key) else null
	var new_token: String = "actor_%s" % Crypto.new().generate_random_bytes(16).hex_encode()
	var undo: EditorUndoRedoManager = host_plugin.get_undo_redo()
	undo.create_action("Assign Entity Instance ID", UndoRedo.MERGE_DISABLE, actor)
	undo.add_do_method(actor, "set_meta", metadata_key, StringName(new_token))
	undo.add_undo_method(actor, "set_meta", metadata_key, previous)
	undo.add_do_method(actor, "notify_property_list_changed")
	undo.add_undo_method(actor, "notify_property_list_changed")
	undo.commit_action()


func _edit_authoring(actor_ref: WeakRef) -> void:
	var actor: Node = actor_ref.get_ref() as Node
	if actor == null:
		return
	var authoring: EntityAuthoring = (
		actor.get_meta(_AUTHORING_META) as EntityAuthoring
		if actor.has_meta(_AUTHORING_META)
		else null
	)
	if authoring == null:
		authoring = EntityAuthoring.new()
		authoring.resource_local_to_scene = true
		var previous: Variant = (
			actor.get_meta(_AUTHORING_META) if actor.has_meta(_AUTHORING_META) else null
		)
		var undo: EditorUndoRedoManager = host_plugin.get_undo_redo()
		undo.create_action("Create Scene Composition", UndoRedo.MERGE_DISABLE, actor)
		undo.add_do_method(actor, "set_meta", _AUTHORING_META, authoring)
		undo.add_undo_method(actor, "set_meta", _AUTHORING_META, previous)
		undo.commit_action()
	EditorInterface.edit_resource(authoring)
#endregion


#region Detached preview boundary
func _validate_snapshot(actor_ref: WeakRef, diagnostics_ref: WeakRef) -> void:
	var actor: Node = actor_ref.get_ref() as Node
	var diagnostics: RichTextLabel = diagnostics_ref.get_ref() as RichTextLabel
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if actor == null or diagnostics == null or edited_root == null:
		return
	var snapshot: PackedScene = EntityAuthoringSnapshotRules.capture(edited_root)
	if snapshot == null:
		diagnostics.text = "Cannot capture scene"
		return
	var directory: String = ProjectSettings.globalize_path("res://").path_join(_PREVIEW_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(directory)
	var scene_file: String = directory.path_join("snapshot.tscn")
	var result_file: String = directory.path_join("result.json")
	if ResourceSaver.save(snapshot, scene_file) != OK:
		diagnostics.text = "Cannot save disposable scene snapshot"
		return
	if FileAccess.file_exists(result_file):
		DirAccess.remove_absolute(result_file)
	var arguments: PackedStringArray = PackedStringArray(
		[
			"--headless",
			"--quit-after",
			"2",
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			_PREVIEW_RUNNER,
			"--",
			scene_file,
			result_file,
		]
	)
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	var worker_log: String = "\n".join(output)
	var log_file: FileAccess = FileAccess.open(directory.path_join("last.log"), FileAccess.WRITE)
	if log_file != null:
		log_file.store_string(worker_log)
		log_file.close()
	if "SCRIPT ERROR:" in worker_log or "Parse Error:" in worker_log:
		diagnostics.text = "Preview script failed. Diagnostics: %s" % directory.path_join(
			"last.log"
		)
		return
	if not FileAccess.file_exists(result_file):
		diagnostics.text = "Preview failed (%d): %s" % [exit_code, "\n".join(output)]
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(result_file))
	if not parsed is Dictionary or not (parsed as Dictionary).get("actors") is Array:
		diagnostics.text = "Preview returned invalid diagnostics"
		return
	var report: Dictionary = parsed as Dictionary
	var actor_path: String = String(edited_root.get_path_to(actor))
	diagnostics.text = _diagnostic_text(report, actor_path)
	DirAccess.remove_absolute(scene_file)
	DirAccess.remove_absolute(result_file)


func _diagnostic_text(report: Dictionary, actor_path: String) -> String:
	var lines: PackedStringArray = PackedStringArray(
		["Scene: %s" % ("PASS" if report.get("valid", false) else "FAIL")]
	)
	for message: Variant in report.get("issues", []):
		lines.append(String(message))
	for entry: Dictionary in report.get("actors", []):
		if entry.path != actor_path:
			continue
		lines.append("Traits: %s" % ", ".join(entry.traits))
		for issue: Dictionary in entry.issues:
			lines.append("%s: %s (%s)" % [issue.code, issue.message, issue.source])
		if _advanced:
			lines.append(JSON.stringify(entry.providers, "\t"))
			lines.append("Bindings: %s" % JSON.stringify(entry.bindings, "\t"))
	return "\n".join(lines)
#endregion
