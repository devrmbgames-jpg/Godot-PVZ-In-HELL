extends RefCounted
## Release the pinned DialogueManager's per-line resource self references after a session.
class_name DialogueResourceLifecycle


static func release_runtime_references(resource: DialogueResource) -> void:
	if resource == null:
		return
	# DialogueManager.get_line adds data.resource to the shared compiled dictionary.
	# This forms resource -> lines -> resource; authored line data has no such key.
	for value: Variant in resource.lines.values():
		var data: Dictionary = value as Dictionary
		if data.get("resource") == resource:
			data.erase("resource")
