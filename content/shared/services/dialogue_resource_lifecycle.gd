extends RefCounted
## Удаляет циклические ссылки ресурса DialogueManager из словарей реплик после разговора.
class_name DialogueResourceLifecycle


## После завершения либо отменённого await удаляет только добавленные ссылки ресурса на себя.
static func release_runtime_references(resource: DialogueResource) -> void:
	if resource == null:
		return
	_release_cached_graph(resource, { })


#region Cached imported resources
static func _release_cached_graph(
	resource: DialogueResource,
	visited: Dictionary[int, bool],
) -> void:
	var instance_id: int = resource.get_instance_id()
	if visited.has(instance_id):
		return
	visited[instance_id] = true

	# DialogueManager.get_line добавляет data.resource в общий словарь скомпилированных строк.
	# Возникает цикл resource → lines → resource; в авторских данных такого ключа нет.
	for value: Variant in resource.lines.values():
		var data: Dictionary = value as Dictionary
		if data.get("resource") == resource:
			data.erase("resource")

	# Pinned v4.1 imports expose UID@line cue aliases. Only traverse resources already
	# loaded by the conversation; closing a session must not load unused authored imports.
	for value: Variant in resource.cues.values():
		var cue_reference: String = value as String
		if not cue_reference.contains("@"):
			continue
		var uid: int = ResourceUID.text_to_id("uid://" + cue_reference.get_slice("@", 0))
		if not ResourceUID.has_id(uid):
			continue
		var path: String = ResourceUID.get_id_path(uid)
		if not ResourceLoader.has_cached(path):
			continue
		var imported: DialogueResource = load(path) as DialogueResource
		if imported != null:
			_release_cached_graph(imported, visited)
#endregion
