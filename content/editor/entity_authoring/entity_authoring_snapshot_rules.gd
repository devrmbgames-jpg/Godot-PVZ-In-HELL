@tool
extends RefCounted
## Captures current authored Resources while retaining external Scripts, scenes and native assets.
class_name EntityAuthoringSnapshotRules

## Diagnostic origin on copied inputs; never used as gameplay identity or registration state.
const SOURCE_META: StringName = &"_authoring_snapshot_source"


#region Disposable native snapshot
## Copies an edited scene without changing it; only the returned snapshot is saved to scratch space.
static func capture(scene_root: Node) -> PackedScene:
	var detached: Node = scene_root.duplicate()
	var copies: Dictionary[Resource, Resource] = { }
	_capture_node(detached, copies)
	var snapshot: PackedScene = PackedScene.new()
	var result: Error = snapshot.pack(detached)
	detached.free()
	return snapshot if result == OK else null


static func _capture_node(node: Node, copies: Dictionary[Resource, Resource]) -> void:
	for descriptor: Dictionary in node.get_property_list():
		if not int(descriptor.usage) & PROPERTY_USAGE_STORAGE:
			continue
		var property_name: StringName = StringName(descriptor.name)
		var value: Variant = node.get(property_name)
		if value is Resource or value is Array or value is Dictionary:
			node.set(property_name, _capture_value(value, copies))
	for child: Node in node.get_children():
		_capture_node(child, copies)


static func _capture_value(value: Variant, copies: Dictionary[Resource, Resource]) -> Variant:
	if value is Array:
		var array_copy: Array = (value as Array).duplicate()
		for index: int in array_copy.size():
			array_copy[index] = _capture_value(array_copy[index], copies)
		return array_copy
	if value is Dictionary:
		var dictionary_copy: Dictionary = (value as Dictionary).duplicate()
		for key: Variant in dictionary_copy:
			dictionary_copy[key] = _capture_value(dictionary_copy[key], copies)
		return dictionary_copy
	if not value is Resource or value is Script or value is PackedScene:
		return value
	var resource: Resource = value as Resource
	var resource_script: Script = resource.get_script() as Script
	if resource_script == null or not resource_script.resource_path.begins_with("res://content/"):
		return resource
	if copies.has(resource):
		return copies[resource]
	var resource_copy: Resource = resource.duplicate(false)
	copies[resource] = resource_copy
	for descriptor: Dictionary in resource.get_property_list():
		if not int(descriptor.usage) & PROPERTY_USAGE_STORAGE:
			continue
		var property_name: StringName = StringName(descriptor.name)
		if property_name in [&"script", &"resource_path"]:
			continue
		resource_copy.set(property_name, _capture_value(resource.get(property_name), copies))
	# The concrete Script already identifies a detached copy. Legacy editor custom-type UID
	# hints describe the original resource, not this disposable instance; keep authored metadata.
	if resource_copy.has_meta(&"_custom_type_script"):
		resource_copy.remove_meta(&"_custom_type_script")
	resource_copy.set_meta(SOURCE_META, resource.resource_path)
	return resource_copy
#endregion
