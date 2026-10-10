@tool
extends RefCounted
## Bounded native signal regression using disposable controls; restores the user's Inspector.

const _PROPERTY_PATH: String = "res://content/editor/entity_authoring/entity_traits_property.gd"
var _busy: bool = false
var _actor: E_TraitedEntity
var _property: EditorProperty


#region Bounded editor verification
## Rejects overlapping work and never changes authored scenes, resources or undo histories.
func inspect(params: Dictionary, context: McpCallContext) -> Dictionary:
	if not params.is_empty() or _busy:
		return { "error": "Signal check accepts no parameters and only one active request." }
	_busy = true
	_run_checks.call_deferred(context)
	return McpDispatcher.DEFERRED_RESPONSE


## Hot swaps must wait until temporary controls and signal connections are released.
func quiesce_for_script_swap() -> Dictionary:
	return { "ok": not _busy }


func _run_checks(context: McpCallContext) -> void:
	var inspector: EditorInspector = EditorInterface.get_inspector()
	var original: WeakRef = weakref(inspector.get_edited_object())
	var failures: PackedStringArray = PackedStringArray()
	var property_script: Script = load(_PROPERTY_PATH) as Script
	var editor_tree: SceneTree = EditorInterface.get_base_control().get_tree()
	inspector.edited_object_changed.connect(_retire_property)
	for operation: StringName in [&"_add_new", &"_make_unique", &"_inspect"]:
		if context.is_expired():
			failures.append("Editor signal request expired")
			break
		_actor = E_TraitedEntity.new()
		_property = property_script.new() as EditorProperty
		EditorInterface.get_base_control().add_child(_property)
		_property.hide()
		_property.set_object_and_property(_actor, &"traits")
		var capability: EntityTrait = EntityTrait.new()
		capability.resource_local_to_scene = true
		_actor.traits = [capability]
		_property.set("_last_traits", _actor.traits.duplicate())
		_property.property_changed.connect(_apply_traits)
		var action: Callable = Callable(_property, operation)
		if operation == &"_make_unique":
			action = action.bind(0)
		elif operation == &"_inspect":
			action = action.bind(capability, true, 0)
		var button: Button = _property.call(
			"_button",
			_property.get("_rows"),
			"Signal lifetime check",
			action,
		) as Button
		button.pressed.emit()
		if not is_instance_valid(button):
			failures.append("%s disposed the source inside its signal" % operation)
		for frame: int in 6:
			await editor_tree.process_frame
		if is_instance_valid(_property):
			failures.append("%s did not switch Inspector after the signal" % operation)
		if not inspector.get_edited_object() is EntityTrait:
			failures.append("%s did not open Trait settings" % operation)
		EditorInterface.inspect_object(null)
		_retire_property()
		_actor.free()
		_actor = null
	inspector.edited_object_changed.disconnect(_retire_property)
	EditorInterface.inspect_object(original.get_ref())
	_busy = false
	context.send_deferred(
		{
			"data": {
				"ok": failures.is_empty(),
				"assertions": 9,
				"failures": failures,
				"authored_content_changed": false,
				"inspector_restored": inspector.get_edited_object() == original.get_ref(),
			},
		}
	)


func _apply_traits(
	_property_name: StringName,
	updated: Variant,
	_field: StringName,
	_changing: bool,
) -> void:
	_actor.traits = updated as Array[EntityTrait]


func _retire_property() -> void:
	# Rebuilding Inspector disposes the property and its originating controls.
	if is_instance_valid(_property):
		_property.free()
	_property = null
#endregion
