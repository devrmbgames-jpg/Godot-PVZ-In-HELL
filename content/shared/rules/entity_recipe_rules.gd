extends RefCounted
## Copies compiler recipes with independent nested mutable state and shared immutable Definitions.
class_name EntityRecipeRules


#region Fresh recipe state
## Returns one independent recipe, retaining immutable Definitions/assets and scene Node identities.
## Non-export script fields are copied because pinned GECS also preserves their initial values.
static func copy_component(recipe: Component) -> Component:
	var copied_references: Dictionary[int, RefCounted] = { }
	return _copy_reference(recipe, copied_references) as Component


static func _copy_reference(
	source_reference: RefCounted,
	copied_references: Dictionary[int, RefCounted],
) -> RefCounted:
	# Definitions and authored engine assets are references, not writable runtime records.
	if (
		(
			(
				source_reference is GameDefinition or source_reference is Script \
						or source_reference is PackedScene
				or source_reference is Texture
			) \
					or source_reference is Shader
			or source_reference is Material
		) \
				or source_reference is AudioStream
		or source_reference is Animation
	):
		return source_reference

	var record_script: Script = source_reference.get_script() as Script
	if _is_definition_script(record_script):
		return source_reference

	var source_identity: int = source_reference.get_instance_id()
	if copied_references.has(source_identity):
		return copied_references[source_identity]

	if record_script == null:
		if source_reference is Resource:
			var native_source: Resource = source_reference as Resource
			var native_copy: Resource = native_source.duplicate(true)
			copied_references[source_identity] = native_copy
			return native_copy
		# Native weak references describe identity/lifetime, not writable aggregate records.
		return source_reference

	var record_copy: RefCounted = record_script.new() as RefCounted
	copied_references[source_identity] = record_copy

	# Keep container types and record aliasing inside this one Component aggregate.
	# Component.parent is a live engine binding established later by GECS registration.
	for descriptor: Dictionary in source_reference.get_property_list():
		var usage: int = int(descriptor.usage)
		if not usage & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var field_name: StringName = StringName(descriptor.name)
		if field_name == &"script" or field_name == &"resource_path":
			continue
		if source_reference is Component and field_name == &"parent":
			continue
		var initial_value: Variant = source_reference.get(field_name)
		record_copy.set(field_name, _copy_value(initial_value, copied_references))
	return record_copy


static func _is_definition_script(record_script: Script) -> bool:
	# Canonical DEF_* Profiles also include Resource-based definitions such as impact tuning.
	# Their shared immutable role does not depend on inheriting GameDefinition's key contract.
	while record_script != null:
		var source_path: String = record_script.resource_path
		var canonical_root: bool = source_path.begins_with("res://content/domains/") \
				or source_path.begins_with("res://content/shared/")
		if canonical_root and "/definitions/" in source_path \
				and String(record_script.get_global_name()).begins_with("DEF_"):
			return true
		record_script = record_script.get_base_script()
	return false


static func _copy_value(
	initial_value: Variant,
	copied_references: Dictionary[int, RefCounted],
) -> Variant:
	if initial_value is RefCounted:
		return _copy_reference(initial_value as RefCounted, copied_references)

	if initial_value is Array:
		var original_items: Array = initial_value as Array
		var copied_items: Array = original_items.duplicate()
		for item_index: int in original_items.size():
			copied_items[item_index] = _copy_value(original_items[item_index], copied_references)
		return copied_items

	if initial_value is Dictionary:
		var original_fields: Dictionary = initial_value as Dictionary
		var copied_fields: Dictionary = original_fields.duplicate()
		copied_fields.clear()
		for original_key: Variant in original_fields:
			var copied_key: Variant = _copy_value(original_key, copied_references)
			copied_fields[copied_key] = _copy_value(
				original_fields[original_key],
				copied_references,
			)
		return copied_fields

	# Copy packed containers explicitly; Node references remain immutable binding identities.
	match typeof(initial_value):
		TYPE_PACKED_BYTE_ARRAY:
			var byte_values: PackedByteArray = initial_value
			return byte_values.duplicate()
		TYPE_PACKED_INT32_ARRAY:
			var int32_values: PackedInt32Array = initial_value
			return int32_values.duplicate()
		TYPE_PACKED_INT64_ARRAY:
			var int64_values: PackedInt64Array = initial_value
			return int64_values.duplicate()
		TYPE_PACKED_FLOAT32_ARRAY:
			var float32_values: PackedFloat32Array = initial_value
			return float32_values.duplicate()
		TYPE_PACKED_FLOAT64_ARRAY:
			var float64_values: PackedFloat64Array = initial_value
			return float64_values.duplicate()
		TYPE_PACKED_STRING_ARRAY:
			var string_values: PackedStringArray = initial_value
			return string_values.duplicate()
		TYPE_PACKED_VECTOR2_ARRAY:
			var vector2_values: PackedVector2Array = initial_value
			return vector2_values.duplicate()
		TYPE_PACKED_VECTOR3_ARRAY:
			var vector3_values: PackedVector3Array = initial_value
			return vector3_values.duplicate()
		TYPE_PACKED_VECTOR4_ARRAY:
			var vector4_values: PackedVector4Array = initial_value
			return vector4_values.duplicate()
		TYPE_PACKED_COLOR_ARRAY:
			var color_values: PackedColorArray = initial_value
			return color_values.duplicate()
	return initial_value
#endregion
