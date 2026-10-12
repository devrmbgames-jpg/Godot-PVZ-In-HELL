@tool
extends RefCounted
## Native player capability save preserving packed GECS fields absent from editor placeholders.

const TARGET: String = "res://content/domains/motion/entities/character_body_player.tscn"
const SOURCE: String = "res://.artifacts/player_before_soul.tscn"
const TRAIT: String = "res://content/domains/npc/authoring/et_player_soul_trade.tres"


#region Guarded native editor save
## Restores the clean fingerprinted player graph and appends its soul capability.
func save(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	if not Engine.is_editor_hint() or not EditorInterface.get_unsaved_scenes().is_empty():
		return { "error": "A connected editor with clean scenes is required." }
	if (
		String(params.get("source_fingerprint", "")) != FileAccess.get_sha256(SOURCE)
		or String(params.get("target_fingerprint", "")) != FileAccess.get_sha256(TARGET)
	):
		return { "error": "Player checkpoint or target changed before native save." }
	var source: PackedScene = ResourceLoader.load(
		SOURCE,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP,
	) as PackedScene
	var capability: EntityTrait = ResourceLoader.load(
		TRAIT,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP,
	) as EntityTrait
	if source == null or capability == null:
		return { "error": "Missing player checkpoint or authored soul capability." }
	var prepared: Dictionary = append_trait(source, capability)
	if prepared.has("error"):
		return prepared
	var uid: int = ResourceLoader.get_resource_uid(TARGET)
	if uid == ResourceUID.INVALID_ID or ResourceLoader.get_resource_uid(SOURCE) != uid:
		return { "error": "Player checkpoint must retain the current target UID." }
	var scene: PackedScene = prepared.scene as PackedScene
	var error: Error = ResourceSaver.save(scene, TARGET)
	if error == OK:
		error = ResourceSaver.set_uid(TARGET, uid)
	if error != OK:
		return { "error": error_string(error) }
	EditorInterface.get_resource_filesystem().update_file(TARGET)
	EditorInterface.reload_scene_from_path(TARGET)
	return {
		"data": {
			"saved": TARGET,
			"uid_preserved": true,
			"packed_fields_preserved": true,
			"undoable": false,
		}
	}
#endregion


#region Pure packed-state authoring
## Changes exactly one packed root-capability value; no Node instantiation or gameplay registration.
static func append_trait(source: PackedScene, capability: EntityTrait) -> Dictionary:
	var state: SceneState = source.get_state()
	if state.get_node_count() == 0 or state.get_node_type(0) != &"CharacterBody3D":
		return { "error": "Expected the native player root." }
	var root_traits: Array = []
	var recipes: Array = []
	for index: int in state.get_node_property_count(0):
		var property: StringName = state.get_node_property_name(0, index)
		if property == &"traits":
			root_traits = state.get_node_property_value(0, index) as Array
		elif property == &"component_resources":
			recipes = state.get_node_property_value(0, index) as Array
	if root_traits.is_empty() or recipes.is_empty() or capability.trait_id != &"player_soul_trade":
		return { "error": "Checkpoint must retain root traits and authored component recipes." }
	var has_health: bool = false
	var has_strength: bool = false
	for component: Component in recipes:
		has_health = has_health or component is C_Health
		has_strength = has_strength or component is C_Strength
	if not has_health or not has_strength:
		return { "error": "Checkpoint must retain Health and Strength." }
	var updated: Array[EntityTrait] = []
	for existing: EntityTrait in root_traits:
		if existing.trait_id == capability.trait_id:
			return { "error": "Soul capability already exists in checkpoint." }
		updated.append(existing)
	updated.append(capability)
	var bundled: Dictionary = (source.get("_bundled") as Dictionary).duplicate()
	var variants: Array = (bundled.variants as Array).duplicate()
	var replacements: int = 0
	for index: int in variants.size():
		if variants[index] is Array and is_same(variants[index], root_traits):
			variants[index] = updated
			replacements += 1
	if replacements != 1:
		return { "error": "Root capability array must have one unambiguous packed value." }
	bundled.variants = variants
	var scene: PackedScene = PackedScene.new()
	scene.set("_bundled", bundled)
	return { "scene": scene }
#endregion
