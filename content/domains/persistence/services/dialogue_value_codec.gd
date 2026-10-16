extends RefCounted
## Явный value graph авторских параметров без служебных ключей внутри пользовательских словарей.
class_name DialogueValueCodec


#region Отделённое кодирование
## Упаковывает тип и данные; ошибка содержит путь, но никогда не сохраняет живой Object.
## Бюджет ограничивает рекурсию, включая циклические Array/Dictionary.
static func encode(value: Variant, path: String, budget: int) -> Dictionary:
	if budget < 0:
		return _invalid(path, "превышена глубина или контейнер содержит цикл")
	var kind: int = typeof(value)
	if not _data_type(kind):
		return _invalid(path, "тип %s не поддерживается сохранением" % type_string(kind))

	var result: Dictionary = { "kind": kind, "value": value }
	if value is Array:
		var source: Array = value as Array
		if not _data_type(source.get_typed_builtin()):
			return _invalid(path, "типизированный Array содержит Object или другой runtime-тип")
		var entries: Array[Dictionary] = []
		for index: int in source.size():
			var entry: Dictionary = encode(source[index], "%s[%d]" % [path, index], budget - 1)
			if entry.has("invalid"):
				return entry
			entries.append(entry)
		result.value = entries
		result["element_type"] = source.get_typed_builtin()
	elif value is Dictionary:
		var source: Dictionary = value as Dictionary
		if (
			not _data_type(source.get_typed_key_builtin())
			or not _data_type(source.get_typed_value_builtin())
		):
			return _invalid(path, "типизированный Dictionary содержит runtime-тип")
		var entries: Array[Array] = []
		var index: int = 0
		for key: Variant in source:
			var encoded_key: Dictionary = encode(key, "%s.key[%d]" % [path, index], budget - 1)
			var value_path: String = "%s.value[%d]" % [path, index]
			if typeof(key) in [TYPE_STRING, TYPE_STRING_NAME]:
				value_path = "%s[%s]" % [path, key]
			var encoded_value: Dictionary = encode(source[key], value_path, budget - 1)
			if encoded_key.has("invalid"):
				return encoded_key
			if encoded_value.has("invalid"):
				return encoded_value
			entries.append([encoded_key, encoded_value])
			index += 1
		result.value = entries
		result["key_type"] = source.get_typed_key_builtin()
		result["value_type"] = source.get_typed_value_builtin()
	elif kind >= TYPE_PACKED_BYTE_ARRAY:
		result.value = value.duplicate()
	return result
#endregion


#region Проверенное восстановление
## Возвращает {ok, value}; ok отличает явный null от отказа. Не загружает Scripts/Resources.
static func decode(encoded: Variant, budget: int) -> Dictionary:
	if budget < 0 or not encoded is Dictionary:
		return { "ok": false }
	var wire: Dictionary = encoded as Dictionary
	if not wire.get("kind") is int or not wire.has("value"):
		return { "ok": false }
	var kind: int = wire.kind
	if not _data_type(kind):
		return { "ok": false }
	if kind == TYPE_ARRAY:
		return _decode_array(wire, budget)
	if kind == TYPE_DICTIONARY:
		return _decode_dictionary(wire, budget)
	if wire.size() != 2 or typeof(wire.value) != kind:
		return { "ok": false }
	var value: Variant = wire.value
	if kind >= TYPE_PACKED_BYTE_ARRAY:
		value = value.duplicate()
	return { "ok": true, "value": value }


static func _decode_array(wire: Dictionary, budget: int) -> Dictionary:
	if (
		wire.size() != 3 or not wire.value is Array
		or not wire.get("element_type") is int or not _data_type(wire.element_type)
	):
		return { "ok": false }
	var element_type: int = wire.element_type
	var entries: Array = []
	for encoded_entry: Variant in wire.value:
		var entry: Dictionary = decode(encoded_entry, budget - 1)
		if not entry.ok or not _matches(entry.value, element_type):
			return { "ok": false }
		entries.append(entry.value)
	var restored: Array = Array(entries, element_type, &"", null)
	return { "ok": true, "value": restored }


static func _decode_dictionary(wire: Dictionary, budget: int) -> Dictionary:
	if (
		wire.size() != 4 or not wire.value is Array or not wire.get("key_type") is int
		or not wire.get("value_type") is int
		or not _data_type(wire.key_type) or not _data_type(wire.value_type)
	):
		return { "ok": false }
	var entries: Dictionary = { }
	for pair: Variant in wire.value:
		if not pair is Array or pair.size() != 2:
			return { "ok": false }
		var key: Dictionary = decode(pair[0], budget - 1)
		var entry: Dictionary = decode(pair[1], budget - 1)
		if (
			not key.ok or not entry.ok or not _matches(key.value, wire.key_type)
			or not _matches(entry.value, wire.value_type)
		):
			return { "ok": false }
		if entries.has(key.value):
			return { "ok": false }
		entries[key.value] = entry.value
	var restored: Dictionary = Dictionary(
		entries,
		wire.key_type,
		&"",
		null,
		wire.value_type,
		&"",
		null,
	)
	return { "ok": true, "value": restored }
#endregion


#region Диагностика captured snapshot
## Находит первую авторскую причину в отделённом результате SaveDataCodec.encode.
## Используется только после неудачного preflight, до любой записи файла.
static func snapshot_error(value: Variant) -> String:
	if value is Dictionary:
		var fields: Dictionary = value as Dictionary
		if fields.get("invalid") == true and fields.get("error") is String:
			return fields.error
		for entry: Variant in fields.values():
			var diagnostic: String = snapshot_error(entry)
			if not diagnostic.is_empty():
				return diagnostic
	elif value is Array:
		for entry: Variant in value:
			var diagnostic: String = snapshot_error(entry)
			if not diagnostic.is_empty():
				return diagnostic
	return ""
#endregion


#region Ограничения value graph
static func _data_type(kind: int) -> bool:
	return (
		kind >= TYPE_NIL and kind < TYPE_MAX
		and kind not in [TYPE_OBJECT, TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL]
	)


static func _matches(value: Variant, expected: int) -> bool:
	return expected == TYPE_NIL or typeof(value) == expected


static func _invalid(path: String, reason: String) -> Dictionary:
	return { "invalid": true, "error": "Память диалога %s: %s" % [path, reason] }
#endregion
