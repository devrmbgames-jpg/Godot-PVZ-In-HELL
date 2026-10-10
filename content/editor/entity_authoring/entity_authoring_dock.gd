@tool
extends VBoxContainer
## Scene-authored editor dock; native resources and detached preview keep their existing owners.

const _AUTHORING_META: StringName = &"entity_composition"
const _LOCAL_ID_META: StringName = &"persistent_local_id"
const _WORLD_ID_META: StringName = &"persistent_world_id"
const _PREVIEW_RUNNER: String = "res://utils/preview_entity_authoring.gd"
const _PREVIEW_DIRECTORY: String = ".artifacts/authoring_preview"

## Plugin owns native undo; cleared when the dock leaves the editor.
var host_plugin: EditorPlugin = null
var _actor_ref: WeakRef
var _root_ref: WeakRef
var _authoring_ref: WeakRef
var _advanced: bool = false
var _resource_inspector: EditorInspector

@onready var _selection_label: Label = %Selection
@onready var _instance_id: Label = %InstanceId
@onready var _level_id: Label = %LevelId
@onready var _template_id: Label = %TemplateId
@onready var _repair_instance: Button = %RepairInstance
@onready var _repair_level: Button = %RepairLevel
@onready var _configure: Button = %Configure
@onready var _validate: Button = %Validate
@onready var _advanced_toggle: CheckButton = %Advanced
@onready var _recipes: RichTextLabel = %Recipes
@onready var _diagnostics: RichTextLabel = %Diagnostics
@onready var _resource_host: VBoxContainer = %ResourceInspector


#region Dock presentation and selection
func _ready() -> void:
	# Native property editors belong to the plugin, not the authored scene's runtime graph.
	if host_plugin == null:
		return
	_resource_inspector = EditorInspector.create_default_inspector()
	_resource_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_resource_host.add_child(_resource_inspector)
	_repair_instance.pressed.connect(_repair_selected_instance)
	_repair_level.pressed.connect(_repair_selected_level)
	_configure.pressed.connect(_configure_selected)
	_validate.pressed.connect(_validate_snapshot)
	_advanced_toggle.toggled.connect(_set_advanced)
	_resource_inspector.resource_selected.connect(_open_resource)
	_resource_inspector.property_edited.connect(_resource_edited)
	bind_actor(null, null)


func _exit_tree() -> void:
	_disconnect_identity_signals()
	host_plugin = null


## Selection is editor-owned; weak references never extend an edited scene's lifetime.
func bind_actor(actor: Node, edited_root: Node) -> void:
	_disconnect_identity_signals()
	_actor_ref = weakref(actor) if actor != null else null
	_root_ref = weakref(edited_root) if edited_root != null else null
	if actor != null:
		actor.property_list_changed.connect(_refresh_identity)
	if edited_root != null and edited_root != actor:
		edited_root.property_list_changed.connect(_refresh_identity)
	_diagnostics.text = ""
	_refresh_identity()
	var authoring: EntityAuthoring = (
		actor.get_meta(_AUTHORING_META) as EntityAuthoring
		if actor is Entity and actor.has_meta(_AUTHORING_META)
		else null
	)
	if _resource_inspector != null:
		_resource_inspector.edit(authoring)


func _disconnect_identity_signals() -> void:
	var actor: Node = _actor_ref.get_ref() as Node if _actor_ref != null else null
	var edited_root: Node = _root_ref.get_ref() as Node if _root_ref != null else null
	for identity_owner: Node in [actor, edited_root]:
		if identity_owner != null and identity_owner.property_list_changed.is_connected(
				_refresh_identity
			):
			identity_owner.property_list_changed.disconnect(_refresh_identity)


func _refresh_identity() -> void:
	var actor: Node = _actor_ref.get_ref() as Node if _actor_ref != null else null
	var edited_root: Node = _root_ref.get_ref() as Node if _root_ref != null else null
	_selection_label.text = (
		"Selected: %s" % actor.name if actor != null else "Select an Entity or level"
	)
	_instance_id.visible = actor is Entity
	_instance_id.text = "Instance ID: %s" % (
		actor.get_meta(_LOCAL_ID_META, "unassigned") if actor != null else "unassigned"
	)
	_level_id.text = "Level ID: %s" % (
		edited_root.get_meta(_WORLD_ID_META, "prefab / unassigned")
		if edited_root != null
		else "no edited scene"
	)
	var authoring: EntityAuthoring = (
		actor.get_meta(_AUTHORING_META) as EntityAuthoring
		if actor is Entity and actor.has_meta(_AUTHORING_META)
		else null
	)
	var previous_authoring: Resource = (
		_authoring_ref.get_ref() as Resource if _authoring_ref != null else null
	)
	if authoring != previous_authoring or (authoring == null and _authoring_ref != null):
		_authoring_ref = weakref(authoring) if authoring != null else null
		if _resource_inspector != null:
			_resource_inspector.edit(authoring)
	_template_id.visible = actor is Entity
	_template_id.text = "Template ID: %s" % (
		authoring.entity_template.key
		if authoring != null and authoring.entity_template != null
		else "scene intrinsic"
	)
	_repair_instance.disabled = host_plugin == null or not actor is Entity
	_repair_level.disabled = (host_plugin == null or edited_root == null or edited_root is Entity)
	_configure.disabled = host_plugin == null or not actor is Entity
	_validate.disabled = host_plugin == null or actor == null or edited_root == null
	_recipes.visible = _advanced
	var recipes: PackedStringArray = PackedStringArray(["Scene Component recipes:"])
	if actor is Entity:
		for component: Resource in (actor as Entity).component_resources:
			if component == null:
				recipes.append("Missing Component recipe: validate for missing_recipe diagnostics")
			else:
				recipes.append(str(component) + " / " + component.resource_path)
	_recipes.text = "\n".join(recipes)


func _repair_selected_instance() -> void:
	_repair_identity(_actor_ref, _LOCAL_ID_META)


func _repair_selected_level() -> void:
	_repair_identity(_root_ref, _WORLD_ID_META)


func _configure_selected() -> void:
	_edit_authoring(_actor_ref)


func _set_advanced(enabled: bool) -> void:
	_advanced = enabled
	_refresh_identity()


func _open_resource(resource: Resource, _property_path: String) -> void:
	_resource_inspector.edit(resource)


func _resource_edited(_property_name: String) -> void:
	_refresh_identity()
#endregion


#region Explicit undoable identity operation
func _repair_identity(actor_ref: WeakRef, metadata_key: StringName) -> void:
	var actor: Node = actor_ref.get_ref() as Node
	if actor == null:
		return
	var previous: Variant = actor.get_meta(metadata_key) if actor.has_meta(metadata_key) else null
	var new_token: String = "actor_%s" % Crypto.new().generate_random_bytes(16).hex_encode()
	var undo: EditorUndoRedoManager = host_plugin.get_undo_redo()
	var action_name: String = (
		"Assign Level ID" if metadata_key == _WORLD_ID_META else "Assign Entity Instance ID"
	)
	undo.create_action(action_name, UndoRedo.MERGE_DISABLE, actor)
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
		undo.add_do_method(actor, "notify_property_list_changed")
		undo.add_undo_method(actor, "notify_property_list_changed")
		undo.commit_action()
	_resource_inspector.edit(authoring)
#endregion


#region Detached preview boundary
func _validate_snapshot() -> void:
	var actor_ref: WeakRef = _actor_ref
	var diagnostics_ref: WeakRef = weakref(_diagnostics)
	var actor: Node = actor_ref.get_ref() as Node if actor_ref != null else null
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
		if actor_path != "." and entry.path != actor_path:
			continue
		if actor_path == ".":
			lines.append("Actor: %s" % entry.path)
		lines.append("Traits: %s" % ", ".join(entry.traits))
		for issue: Dictionary in entry.issues:
			lines.append("%s: %s (%s)" % [issue.code, issue.message, issue.source])
		if _advanced:
			lines.append(JSON.stringify(entry.providers, "\t"))
			lines.append("Bindings: %s" % JSON.stringify(entry.bindings, "\t"))
	return "\n".join(lines)
#endregion
