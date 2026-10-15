@tool
extends RefCounted
## Appends a physical item to the fingerprinted morning catalog using an isolated native graph.

const SUPPLY: String = "res://content/domains/packages/definitions/def_delivery_morning_supply.tres"
const ITEM_ROOT: String = "res://content/domains/inventory/definitions/"


#region Editor authoring transaction
## Preserves the supply graph and UID; refuses dirty scenes and an inspected target.
## File save precedes UID restoration; a later error does not undo the already written file.
func append_item(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	if not Engine.is_editor_hint() or not EditorInterface.get_unsaved_scenes().is_empty():
		return { "error": "Catalog authoring requires the editor with saved scenes." }
	var inspected: Resource = EditorInterface.get_inspector().get_edited_object() as Resource
	var prepared: Dictionary = preflight(params, inspected)
	if prepared.has("error"):
		return prepared
	var definition: DEF_Delivery = prepared.definition
	var uid: int = ResourceLoader.get_resource_uid(SUPPLY)
	var error: Error = ResourceSaver.save(definition, SUPPLY)
	if error == OK:
		error = ResourceSaver.set_uid(SUPPLY, uid)
	if error != OK:
		return { "error": error_string(error), "path": SUPPLY }
	EditorInterface.get_resource_filesystem().update_file(SUPPLY)
	return { "data": { "saved": SUPPLY, "uid_preserved": true, "undoable": false } }


## Reads disk authority without accepting unsaved cached edits or writing during validation.
static func preflight(params: Dictionary, inspected: Resource = null) -> Dictionary:
	if params.get("fingerprint", "") != FileAccess.get_sha256(SUPPLY):
		return { "error": "Morning supply changed since inspection." }
	if inspected != null and inspected.resource_path.get_slice("::", 0) == SUPPLY:
		return { "error": "Close the morning supply Resource Inspector before authoring." }
	var path: String = params.get("item", "")
	if (
		path.get_base_dir() != ITEM_ROOT.trim_suffix("/")
		or not path.ends_with(".tres") or path.contains("..") or path.contains("::")
		or path.contains("\\") or not ResourceLoader.exists(path)
	):
		return { "error": "Expected an existing authored inventory definition." }
	var definition: DEF_Delivery = ResourceLoader.load(
		SUPPLY,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP,
	) as DEF_Delivery
	var item: DEF_InventoryItem = ResourceLoader.load(
		path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP,
	) as DEF_InventoryItem
	if (
		definition == null or item == null or item.key.is_empty() or item.categories <= 0
		or not item.requires_world_body() or not ResourceLoader.exists(item.world_pickup_scene)
		or ResourceLoader.get_resource_uid(SUPPLY) == ResourceUID.INVALID_ID
	):
		return { "error": "Expected a physical category item and a stable supply UID." }
	return _append_unique(definition, item)


static func _append_unique(definition: DEF_Delivery, item: DEF_InventoryItem) -> Dictionary:
	for existing: DEF_InventoryItem in definition.order_catalog:
		if existing.key == item.key:
			return { "error": "Item key is already present in the morning catalog." }
	definition.order_catalog.append(item)
	return { "definition": definition }
#endregion
