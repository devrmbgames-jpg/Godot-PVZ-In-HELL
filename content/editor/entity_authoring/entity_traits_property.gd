@tool
extends EditorProperty
## Direct array edits use Inspector Undo/Redo, native resource pickers and explicit local copies.

var _rows: VBoxContainer = VBoxContainer.new()
var _file_dialog: EditorFileDialog
var _advanced: RichTextLabel
var _issues: Label
var _last_traits: Array[EntityTrait] = []


#region Native Inspector presentation
func _init() -> void:
	add_child(_rows)
	set_bottom_editor(_rows)
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.tres, *.res ; EntityTrait resources"])
	_file_dialog.file_selected.connect(_add_existing)
	add_child(_file_dialog)


func _update_property() -> void:
	var actor: E_TraitedEntity = get_edited_object() as E_TraitedEntity
	if actor == null:
		return
	_last_traits = actor.traits.duplicate()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for index: int in actor.traits.size():
		_add_row(actor.traits[index], index)
	var commands: HBoxContainer = HBoxContainer.new()
	_rows.add_child(commands)
	_button(commands, "Add Trait", _choose_existing)
	_button(commands, "New Trait", _add_new)
	_button(_rows, "Validate Scene Composition", _validate_scene)
	_issues = Label.new()
	_issues.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(_issues)
	var advanced_toggle: CheckButton = CheckButton.new()
	advanced_toggle.text = "Advanced diagnostics"
	_rows.add_child(advanced_toggle)
	_advanced = RichTextLabel.new()
	_advanced.fit_content = true
	_advanced.selection_enabled = true
	_advanced.visible = false
	_rows.add_child(_advanced)
	advanced_toggle.toggled.connect(
		func(enabled: bool) -> void:
			_advanced.visible = enabled,
	)
	_show_diagnostics(actor)


func _add_row(capability: EntityTrait, index: int) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	_rows.add_child(group)
	var title: Label = Label.new()
	title.text = "%d. %s" % [
		index + 1,
		capability.trait_id if capability != null else "Missing Trait",
	]
	group.add_child(title)
	var picker: EditorResourcePicker = EditorResourcePicker.new()
	picker.base_type = "EntityTrait"
	picker.edited_resource = capability
	group.add_child(picker)
	picker.resource_changed.connect(_assign.bind(index))
	picker.resource_selected.connect(_inspect.bind(index))
	var controls: HBoxContainer = HBoxContainer.new()
	group.add_child(controls)
	_button(controls, "Make Unique & Edit", _make_unique.bind(index)).disabled = capability == null
	_button(controls, "↑", _move.bind(index, -1)).disabled = index == 0
	_button(controls, "↓", _move.bind(index, 1)).disabled = index == _last_traits.size() - 1
	_button(controls, "Remove", _remove.bind(index))


func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)
	add_focusable(button)
	return button
#endregion


#region Undoable direct property changes
func _submit(updated: Array[EntityTrait]) -> void:
	emit_changed(get_edited_property(), updated)


func _choose_existing() -> void:
	_file_dialog.popup_centered_ratio()


func _add_existing(path: String) -> void:
	var capability: EntityTrait = load(path) as EntityTrait
	if capability == null:
		_issues.text = "Choose an EntityTrait resource."
		return
	var updated: Array[EntityTrait] = _last_traits.duplicate()
	updated.append(capability)
	_submit(updated)


func _add_new() -> void:
	var capability: EntityTrait = EntityTrait.new()
	capability.trait_id = &"new_trait"
	capability.resource_local_to_scene = true
	var updated: Array[EntityTrait] = _last_traits.duplicate()
	updated.append(capability)
	_submit(updated)
	EditorInterface.edit_resource(capability)


func _assign(resource: Resource, index: int) -> void:
	if resource != null and not resource is EntityTrait:
		return
	var updated: Array[EntityTrait] = _last_traits.duplicate()
	updated[index] = resource as EntityTrait
	_submit(updated)


func _remove(index: int) -> void:
	var updated: Array[EntityTrait] = _last_traits.duplicate()
	updated.remove_at(index)
	_submit(updated)


func _move(index: int, direction: int) -> void:
	var updated: Array[EntityTrait] = _last_traits.duplicate()
	var capability: EntityTrait = updated[index]
	updated.remove_at(index)
	updated.insert(index + direction, capability)
	_submit(updated)


func _inspect(resource: Resource, _inspect_requested: bool, _index: int) -> void:
	if resource == null:
		return
	if resource.resource_local_to_scene and resource.resource_path.is_empty():
		EditorInterface.edit_resource(resource)
	else:
		_issues.text = "Shared Trait: use Make Unique & Edit to configure this instance."


func _make_unique(index: int) -> void:
	var updated: Array[EntityTrait] = _last_traits.duplicate()
	var capability: EntityTrait = updated[index].duplicate(true) as EntityTrait
	capability.resource_local_to_scene = true
	updated[index] = capability
	_submit(updated)
	EditorInterface.edit_resource(capability)
#endregion


#region Shared detached compiler diagnostics
func _validate_scene() -> void:
	var actor: E_TraitedEntity = get_edited_object() as E_TraitedEntity
	if actor != null:
		_show_diagnostics(actor)


func _show_diagnostics(actor: E_TraitedEntity) -> void:
	# The snapshot includes siblings/ancestors for the runtime endpoint and identity rules.
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	var snapshot: PackedScene = EntityAuthoringSnapshotRules.capture(scene_root)
	if snapshot == null:
		_issues.text = "Cannot capture scene for validation."
		return
	var detached: Node = snapshot.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var report: Dictionary = EntityAuthoringPreviewRules.inspect_scene(detached)
	var actor_path: String = String(scene_root.get_path_to(actor))
	var messages: PackedStringArray = PackedStringArray()
	for message: Variant in report.issues:
		messages.append(String(message))
	for entry: Dictionary in report.actors:
		if entry.path != actor_path:
			continue
		for issue: Dictionary in entry.issues:
			messages.append("%s: %s" % [issue.code, issue.message])
	_advanced.text = JSON.stringify(report, "\t")
	_issues.text = ("Composition valid" if report.valid else "\n".join(messages))
	if not report.valid and messages.is_empty():
		_issues.text = "Other Entities have errors; see Advanced diagnostics."
	detached.free()
#endregion
