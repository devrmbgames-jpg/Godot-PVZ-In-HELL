extends RefCounted
## Удаляет циклические ссылки ресурса DialogueManager из словарей реплик после разговора.
class_name DialogueResourceLifecycle


## После завершения либо отменённого await удаляет только добавленные ссылки ресурса на себя.
static func release_runtime_references(resource: DialogueResource) -> void:
	if resource == null:
		return
	# DialogueManager.get_line добавляет data.resource в общий словарь скомпилированных строк.
	# Возникает цикл resource → lines → resource; в авторских данных такого ключа нет.
	for value: Variant in resource.lines.values():
		var data: Dictionary = value as Dictionary
		if data.get("resource") == resource:
			data.erase("resource")
