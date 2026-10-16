extends GutTest
## Нативные Variant-типы, вложенные контейнеры и закрытый отказ до записи сохранения.


#region Типы и независимость данных
func test_scalar_and_packed_types_roundtrip_without_coercion() -> void:
	var samples: Array = [
		null,
		17,
		2.5,
		true,
		"text",
		&"stable",
		NodePath("literal/data"),
		Vector2(1, 2),
		Vector2i(1, 2),
		Rect2(1, 2, 3, 4),
		Rect2i(1, 2, 3, 4),
		Vector3(1, 2, 3),
		Vector3i(1, 2, 3),
		Transform2D.IDENTITY,
		Vector4(1, 2, 3, 4),
		Vector4i(1, 2, 3, 4),
		Plane(Vector3.UP, 2),
		Quaternion.IDENTITY,
		AABB(Vector3.ZERO, Vector3.ONE),
		Basis.IDENTITY,
		Transform3D.IDENTITY,
		Projection.IDENTITY,
		Color.RED,
		PackedByteArray([1, 2]),
		PackedInt32Array([1, 2]),
		PackedInt64Array([1, 2]),
		PackedFloat32Array([1, 2]),
		PackedFloat64Array([1, 2]),
		PackedStringArray(["a", "b"]),
		PackedVector2Array([Vector2.ONE]),
		PackedVector3Array([Vector3.ONE]),
		PackedColorArray([Color.RED]),
		PackedVector4Array([Vector4.ONE]),
	]
	for sample: Variant in samples:
		var encoded: Dictionary = DialogueValueCodec.encode(
			sample,
			"sample",
			SaveDataCodec.MAX_DEPTH,
		)
		var result: Dictionary = DialogueValueCodec.decode(encoded, SaveDataCodec.MAX_DEPTH)
		assert_true(result.ok, type_string(typeof(sample)))
		assert_eq(typeof(result.value), typeof(sample))
		assert_eq(result.value, sample)


func test_typed_nested_containers_and_reserved_keys_remain_literal_data() -> void:
	var numbers: Array[int] = [1, 2]
	var fields: Dictionary[StringName, Variant] = {
		&"type": "not a Script",
		&"definition": "not a Resource",
		&"invalid": true,
		&"nullable": null,
		&"numbers": numbers,
	}
	var dictionaries: Array[Dictionary] = [fields]
	var encoded: Dictionary = DialogueValueCodec.encode(dictionaries, "sample", 16)
	# Native save serializer also retains wire data without enabling Objects.
	var disk: Variant = bytes_to_var(var_to_bytes(encoded))
	var result: Dictionary = DialogueValueCodec.decode(disk, 16)
	assert_true(result.ok)
	var restored: Array = result.value as Array
	assert_eq(restored.get_typed_builtin(), TYPE_DICTIONARY)
	var restored_fields: Dictionary = restored[0] as Dictionary
	assert_eq(restored_fields.get_typed_key_builtin(), TYPE_STRING_NAME)
	assert_false(restored_fields.is_typed_value())
	assert_eq(restored_fields[&"type"], "not a Script")
	assert_eq(restored_fields[&"definition"], "not a Resource")
	assert_true(restored_fields.has(&"nullable"))
	assert_null(restored_fields[&"nullable"])
	var restored_numbers: Array = restored_fields[&"numbers"] as Array
	assert_eq(restored_numbers.get_typed_builtin(), TYPE_INT)
	numbers.append(3)
	assert_eq(restored_numbers, [1, 2], "capture owns detached container data")


func test_partially_typed_dictionary_preserves_each_wildcard() -> void:
	for source: Dictionary in [
		Dictionary({ 1: true }, TYPE_NIL, &"", null, TYPE_BOOL, &"", null),
		Dictionary({ &"x": 7 }, TYPE_STRING_NAME, &"", null, TYPE_NIL, &"", null),
	]:
		var result: Dictionary = DialogueValueCodec.decode(
			DialogueValueCodec.encode(source, "typed", 16),
			16,
		)
		assert_true(result.ok)
		var restored: Dictionary = result.value as Dictionary
		assert_eq(restored.get_typed_key_builtin(), source.get_typed_key_builtin())
		assert_eq(restored.get_typed_value_builtin(), source.get_typed_value_builtin())
		assert_eq(restored, source)
#endregion


#region Отказ без потери данных
func test_runtime_values_and_even_empty_object_typed_containers_reject() -> void:
	var node: Node = Node.new()
	var objects: Array[Resource] = []
	var object_fields: Dictionary[StringName, Resource] = { }
	for sample: Variant in [
		node,
		Resource.new(),
		RID(),
		Callable(self, "test_runtime_values_and_even_empty_object_typed_containers_reject"),
		node.tree_entered,
		objects,
		object_fields,
		{ "nested": [node] },
	]:
		var encoded: Dictionary = DialogueValueCodec.encode(
			sample,
			"npc/1.dialogue_values[test]",
			16,
		)
		assert_true(encoded.has("invalid"), type_string(typeof(sample)))
		assert_string_contains(encoded.error, "npc/1.dialogue_values[test]")
		assert_false(DialogueValueCodec.decode(encoded, 16).ok)
	node.free()


func test_cycles_and_excessive_depth_reject_without_retaining_the_cycle() -> void:
	var cycle: Array = []
	cycle.append(cycle)
	var encoded: Dictionary = DialogueValueCodec.encode(cycle, "cycle", 16)
	assert_true(encoded.has("invalid"))
	cycle.clear()
	var deep: Variant = 1
	for level: int in 18:
		deep = [deep]
	assert_true(DialogueValueCodec.encode(deep, "deep", 16).has("invalid"))


func test_malformed_wire_cannot_coerce_types_or_construct_objects() -> void:
	for malformed: Variant in [
		null,
		{ "kind": TYPE_OBJECT, "value": null },
		{ "kind": TYPE_INT, "value": 1.0 },
		{ "kind": TYPE_INT, "value": 1, "extra": true },
		{ "kind": TYPE_ARRAY, "value": [], "element_type": TYPE_OBJECT },
		{
			"kind": TYPE_ARRAY,
			"value": [{ "kind": TYPE_STRING, "value": "7" }],
			"element_type": TYPE_INT,
		},
		{
			"kind": TYPE_DICTIONARY,
			"value": [[{ "kind": TYPE_INT, "value": 7 }]],
			"key_type": TYPE_INT,
			"value_type": TYPE_NIL,
		},
		{ "kind": TYPE_DICTIONARY, "value": [], "key_type": -1, "value_type": TYPE_NIL },
	]:
		assert_false(DialogueValueCodec.decode(malformed, 16).ok)
#endregion
