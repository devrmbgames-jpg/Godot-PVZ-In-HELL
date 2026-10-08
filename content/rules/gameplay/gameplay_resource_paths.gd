extends RefCounted
## Чистая классификация native resource paths по approved domain/shared role roots.
class_name GameplayResourcePaths

const _OWNERS: Array[String] = [
	"challenges",
	"combat",
	"commerce",
	"customers",
	"hazards",
	"interaction",
	"inventory",
	"motion",
	"needs",
	"npc",
	"packages",
	"persistence",
	"quests",
	"time",
]

#region Closed native resource roles
## Принимает только entity-prefab role roots выбранных owners.
static func is_entity_scene_path(path: String) -> bool:
	return _role_path_allowed(path, "entities")


## Принимает authored Definition roles; legacy Shared resources переезжают в task 32.
static func is_definition_path(path: String) -> bool:
	return path.begins_with("res://content/definitions/") or _role_path_allowed(path, "definitions")


static func _role_path_allowed(path: String, role: String) -> bool:
	if path.begins_with("res://content/shared/" + role + "/"):
		return true
	for domain: String in _OWNERS:
		if path.begins_with("res://content/domains/" + domain + "/" + role + "/"):
			return true
	return false
#endregion
