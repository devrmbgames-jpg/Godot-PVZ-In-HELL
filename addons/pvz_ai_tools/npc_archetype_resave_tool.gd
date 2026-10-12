@tool
extends RefCounted
## Canonical native resave of fingerprinted NPC definitions without replacing their resource graph.

const ROOT: String = "res://content/domains/npc/definitions/"
const MAXIMUM_PATHS: int = 8


#region Editor transaction
## Requires clean scenes, an uninspected target and the exact reviewed file fingerprints.
func resave(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	if not Engine.is_editor_hint():
		return { "error": "Canonical resave requires the editor." }
	if not EditorInterface.get_unsaved_scenes().is_empty():
		return { "error": "Save unsaved scenes before canonical resource resave." }
	var hashes: Dictionary = params.get("fingerprints", { })
	var inspected: Resource = EditorInterface.get_inspector().get_edited_object() as Resource
	var prepared: Dictionary = preflight(hashes, inspected)
	if prepared.has("error"):
		return prepared
	var resources: Array[Resource] = prepared.resources
	var completed: PackedStringArray = []
	for resource: Resource in resources:
		var path: String = resource.resource_path
		var uid: int = ResourceLoader.get_resource_uid(path)
		var error: Error = ResourceSaver.save(resource, path)
		if error == OK:
			error = ResourceSaver.set_uid(path, uid)
		if error != OK:
			return { "error": error_string(error), "path": path, "saved": completed }
		EditorInterface.get_resource_filesystem().update_file(path)
		completed.append(path)
	return { "data": { "saved": completed, "uids_preserved": true, "undoable": false } }
#endregion


#region Complete preflight
## Loads a separate native graph; cached Inspector edits cannot enter the saved files.
static func preflight(fingerprints: Dictionary, inspected: Resource = null) -> Dictionary:
	if fingerprints.is_empty() or fingerprints.size() > MAXIMUM_PATHS:
		return { "error": "Expected one to eight fingerprinted NPC definitions." }
	var resources: Array[Resource] = []
	for key: Variant in fingerprints:
		if not key is String:
			return { "error": "Resource paths must be strings." }
		var path: String = key
		if (
			path.get_base_dir() != ROOT.trim_suffix("/") or not path.ends_with(".tres")
			or path.contains("..") or path.contains("::")
			or path.contains("\\") or not ResourceLoader.exists(path)
		):
			return { "error": "Unsupported NPC definition path.", "path": path }
		if inspected != null and inspected.resource_path.get_slice("::", 0) == path:
			return { "error": "Close the target Resource Inspector before resaving.", "path": path }
		if fingerprints[key] != FileAccess.get_sha256(path):
			return { "error": "Resource changed since inspection.", "path": path }
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var resource_script: Script = resource.get_script() as Script if resource != null else null
		if resource_script == null or resource_script != (DEF_NpcArchetype as Script):
			return { "error": "Only DEF_NpcArchetype definitions may be resaved.", "path": path }
		var declared_default: Variant = resource_script.get_property_default_value(
			&"aggressive_speed_multiplier"
		)
		if typeof(declared_default) != TYPE_FLOAT or declared_default != 1.0:
			return { "error": "Restart the editor to refresh the exported script layout." }
		if ResourceLoader.get_resource_uid(path) == ResourceUID.INVALID_ID:
			return { "error": "Authored definition requires a stable UID.", "path": path }
		resources.append(resource)
	return { "resources": resources }
#endregion
