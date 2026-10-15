@tool
extends RefCounted
## Canonical native resave of bounded fingerprinted NPC definition graphs with authored values.

const ROOT: String = "res://content/domains/npc/definitions/"
const MAXIMUM_PATHS: int = 8


#region Editor transaction
## Requires clean scenes, an uninspected target and the exact reviewed file fingerprints.
## Saves files/UIDs sequentially; failure reports earlier completed paths without batch rollback.
func resave(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	if not Engine.is_editor_hint():
		return { "error": "Canonical resave requires the editor." }
	if not EditorInterface.get_unsaved_scenes().is_empty():
		return { "error": "Save unsaved scenes before canonical resource resave." }
	var hashes: Dictionary = params.get("fingerprints", { })
	var pools: Dictionary = params.get("dialogue_pools", { })
	var additions: Dictionary = params.get("trait_additions", { })
	var inspected: Resource = EditorInterface.get_inspector().get_edited_object() as Resource
	var prepared: Dictionary = preflight(hashes, inspected, pools, additions)
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
static func preflight(
	fingerprints: Dictionary,
	inspected: Resource = null,
	dialogue_pools: Dictionary = { },
	trait_additions: Dictionary = { },
) -> Dictionary:
	if fingerprints.is_empty() or fingerprints.size() > MAXIMUM_PATHS:
		return { "error": "Expected one to eight fingerprinted NPC definitions." }
	for pool_path: Variant in dialogue_pools:
		if not fingerprints.has(pool_path) or not dialogue_pools[pool_path] is Array:
			return { "error": "Dialogue pools require a fingerprinted target and an array." }
		var pool: Array = dialogue_pools[pool_path]
		if pool.size() < 2 or pool.size() > 16:
			return { "error": "Expected two to sixteen imported dialogue variants." }
		var seen: Dictionary[String, bool] = { }
		for variant: Variant in pool:
			if not variant is String:
				return { "error": "Dialogue variant paths must be strings." }
			var variant_path: String = variant
			if (
				not variant_path.begins_with("res://") or not variant_path.ends_with(".dialogue")
				or variant_path.contains("..") or variant_path.contains("::")
				or variant_path.contains("\\") or seen.has(variant_path)
				or not ResourceLoader.exists(variant_path)
			):
				return { "error": "Missing, repeated or unsupported dialogue variant." }
			seen[variant_path] = true
	var traits: Dictionary[String, Array] = { }
	for target: Variant in trait_additions:
		if (
			not target is String or not fingerprints.has(target)
			or not trait_additions[target] is Array
		):
			return { "error": "Trait additions require a fingerprinted target and an array." }
		var paths: Array = trait_additions[target]
		if paths.is_empty() or paths.size() > 4:
			return { "error": "Expected one to four existing native trait definitions." }
		traits[target] = []
		var seen: Dictionary[String, bool] = { }
		for entry: Variant in paths:
			if not entry is String:
				return { "error": "Trait definition paths must be strings." }
			var path: String = entry
			if (
				path.get_base_dir() != ROOT.trim_suffix("/") or not path.ends_with(".tres")
				or path.contains("..") or path.contains("::") or path.contains("\\")
				or seen.has(path) or not ResourceLoader.exists(path)
			):
				return { "error": "Missing, repeated or unsupported trait definition." }
			var rule: DEF_NpcTrait = ResourceLoader.load(
				path,
				"",
				ResourceLoader.CACHE_MODE_IGNORE_DEEP,
			) as DEF_NpcTrait
			if rule == null or rule.key.is_empty() or not rule.valid_configuration():
				return { "error": "Expected a valid native NPC trait definition." }
			traits[target].append(rule)
			seen[path] = true
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
		var resource: Resource = ResourceLoader.load(
			path,
			"",
			ResourceLoader.CACHE_MODE_IGNORE_DEEP,
		)
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
		if dialogue_pools.has(path):
			resource.set("dialogue_variants", PackedStringArray(dialogue_pools[path]))
		if traits.has(path):
			var archetype: DEF_NpcArchetype = resource as DEF_NpcArchetype
			for rule: DEF_NpcTrait in traits[path]:
				archetype.rules.append(rule)
			if not archetype.valid_rules():
				return { "error": "Trait addition violates archetype bounds or compatibility." }
		resources.append(resource)
	return { "resources": resources }
#endregion
