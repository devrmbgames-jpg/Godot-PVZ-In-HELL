extends RefCounted
## Синхронные авторские параметры постоянной личности; не заменяют типизированную игровую память.
class_name NpcDialogueMemoryService


#region Авторская коллекция
## Повторная установка флага безопасна; имена значений принадлежат другому пространству.
static func set_tag(person: NpcRecord, tag_name: StringName) -> void:
	person.dialogue_tags[tag_name] = true


## Читает без создания ключа.
static func get_tag(person: NpcRecord, tag_name: StringName) -> bool:
	return person.dialogue_tags.get(tag_name, false)


## Сохраняет исходный Variant, включая null; допустимость для диска проверяет save preflight.
static func set_val(person: NpcRecord, value_name: StringName, value: Variant) -> void:
	person.dialogue_values[value_name] = value


## Отсутствующий ключ возвращает null, не создавая запись.
static func get_val(person: NpcRecord, value_name: StringName) -> Variant:
	return person.dialogue_values.get(value_name)


## Возвращает пустую строку после сложения, иначе понятную причину без изменения коллекции.
## bool не является числом; int + int остаётся int, наличие float даёт float.
static func add_val(person: NpcRecord, value_name: StringName, value: Variant) -> String:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return "add_val(%s): приращение должно быть int/float, получено %s" % [
			value_name,
			type_string(typeof(value)),
		]
	var previous: Variant = person.dialogue_values.get(value_name, 0)
	if typeof(previous) not in [TYPE_INT, TYPE_FLOAT]:
		return "add_val(%s): хранимое значение должно быть int/float, получено %s" % [
			value_name,
			type_string(typeof(previous)),
		]
	person.dialogue_values[value_name] = previous + value
	return ""
#endregion
