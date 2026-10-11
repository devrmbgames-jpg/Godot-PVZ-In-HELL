@tool
extends RefCounted
## Refreshes stale cached archetype definitions after native MCP saves, without changing files.

const ROOT: String = "res://content/domains/npc/definitions/"
const ARCHETYPE_SCRIPT: String = ROOT + "def_npc_archetype.gd"
const MAXIMUM_PATHS: int = 16


#region Editor guard and bounded native cache operation
## Refuses dirty scenes and inspected Resources before refreshing saved definition values.
func refresh(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	if not Engine.is_editor_hint():
		return { "error": "Archetype cache refresh requires the editor." }
	if not EditorInterface.get_unsaved_scenes().is_empty():
		return { "error": "Save unsaved scenes before refreshing authored definition caches." }
	var paths: PackedStringArray = PackedStringArray(params.get("paths", []))
	var inspected: Object = EditorInterface.get_inspector().get_edited_object()
	return refresh_resources(paths, inspected as Resource)


## Preflights every file before native cache refresh; retains no Resources across calls.
static func refresh_resources(paths: PackedStringArray, inspected: Resource = null) -> Dictionary:
	if inspected != null and paths.has(inspected.resource_path.get_slice("::", 0)):
		return { "error": "Close the target Resource Inspector before refreshing its cache." }
	if paths.is_empty() or paths.size() > MAXIMUM_PATHS:
		return { "error": "Expected one to sixteen authored NPC archetypes." }
	var seen: Dictionary[String, bool] = { }
	for path: String in paths:
		if (
			not path.begins_with(ROOT) or not path.ends_with(".tres")
			or path.contains("..") or path.contains("::") or path.contains("\\")
			or path.get_base_dir() != ROOT.trim_suffix("/")
			or seen.has(path) or not ResourceLoader.exists(path)
		):
			return { "error": "Invalid, missing or repeated archetype path.", "path": path }
		seen[path] = true

	var refreshed: Array[Resource] = []
	for path: String in paths:
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var resource_script: Script = resource.get_script() as Script if resource != null else null
		if resource_script == null or resource_script.resource_path != ARCHETYPE_SCRIPT:
			return { "error": "File is not an authored NPC archetype.", "path": path }
		refreshed.append(resource)
	var completed: PackedStringArray = []
	for path: String in paths:
		var replacement: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		var replaced_script: Script = null
		if replacement != null:
			replaced_script = replacement.get_script() as Script
		if replaced_script == null or replaced_script.resource_path != ARCHETYPE_SCRIPT:
			return {
				"error": "Native cache refresh failed.",
				"path": path,
				"refreshed": completed,
				"outcome": "partial" if not completed.is_empty() else "unchanged",
			}
		completed.append(path)
	return {
		"data": {
			"refreshed": paths,
			"files_changed": false,
			"cached_definitions_refreshed": true,
			"scene_reload_required": true,
			"undoable": false,
		}
	}
#endregion
