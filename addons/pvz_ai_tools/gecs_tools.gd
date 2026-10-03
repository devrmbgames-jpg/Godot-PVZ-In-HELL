@tool
extends RefCounted
## Read-only GECS/entity inspection handlers for PVZ Godot AI custom MCP tools.

const DEFAULT_MAX_TYPES: int = 30
const DEFAULT_LIMIT: int = 50
const DEFAULT_COLLECTION_ITEMS: int = 20
const MAX_VALUE_DEPTH: int = 2


#region Public tool handlers

## Returns compact counts for entities, components and relationships.
func world_summary(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	var runtime_result: Dictionary = _runtime_request("world_summary", params, _ctx)
	if not runtime_result.is_empty():
		return runtime_result

	var max_types: int = clampi(int(params.get("max_types", DEFAULT_MAX_TYPES)), 1, 100)
	var source: Dictionary = _entity_source()
	var entities: Array[Entity] = _entities_from_source(source)

	var entity_classes: Dictionary = {}
	var component_classes: Dictionary = {}
	var relationship_classes: Dictionary = {}
	var relationship_count: int = 0

	for entity: Entity in entities:
		if not is_instance_valid(entity):
			continue
		_increment(entity_classes, _object_type(entity))
		for component: Component in _components_for(entity):
			_increment(component_classes, _object_type(component))
		for relationship: Relationship in entity.relationships:
			if relationship == null:
				continue
			relationship_count += 1
			_increment(relationship_classes, _object_type(relationship.relation))

	return {
		"data": {
			"ok": true,
			"source": source.get("source", "unknown"),
			"scene": source.get("scene", ""),
			"entity_count": entities.size(),
			"relationship_count": relationship_count,
			"entity_types": _rank_counts(entity_classes, max_types),
			"component_types": _rank_counts(component_classes, max_types),
			"relationship_types": _rank_counts(relationship_classes, max_types),
			"runtime_note": _runtime_note(source),
		},
	}


## Finds entities using narrow textual/class/component filters.
func find_entities(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	var runtime_result: Dictionary = _runtime_request("find_entities", params, _ctx)
	if not runtime_result.is_empty():
		return runtime_result

	var query: String = String(params.get("query", "")).strip_edges().to_lower()
	var class_filter: String = String(params.get("class_name", "")).strip_edges().to_lower()
	var component_filter: String = String(params.get("component", "")).strip_edges().to_lower()
	var limit: int = clampi(int(params.get("limit", DEFAULT_LIMIT)), 1, 200)
	var source: Dictionary = _entity_source()
	var matches: Array[Dictionary] = []

	for entity: Entity in _entities_from_source(source):
		if not is_instance_valid(entity):
			continue
		var summary: Dictionary = _entity_summary(entity)
		if not class_filter.is_empty() and not String(summary["class_name"]).to_lower().contains(class_filter):
			continue
		if not component_filter.is_empty() and not _entity_has_component_name(entity, component_filter):
			continue
		if not query.is_empty() and not _entity_matches_query(summary, query):
			continue
		matches.append(summary)
		if matches.size() >= limit:
			break

	return {
		"data": {
			"ok": true,
			"source": source.get("source", "unknown"),
			"scene": source.get("scene", ""),
			"matches": matches,
			"returned": matches.size(),
			"limit": limit,
			"runtime_note": _runtime_note(source),
		},
	}


## Inspects one uniquely selected entity and its component state.
func entity_inspect(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	var runtime_result: Dictionary = _runtime_request("entity_inspect", params, _ctx)
	if not runtime_result.is_empty():
		return runtime_result

	var source: Dictionary = _entity_source()
	var resolution: Dictionary = _resolve_entity(params, _entities_from_source(source))
	if not resolution.get("ok", false):
		return {"data": resolution}

	var entity: Entity = resolution["entity"] as Entity
	var include_private: bool = bool(params.get("include_private", false))
	var max_items: int = clampi(
		int(params.get("max_collection_items", DEFAULT_COLLECTION_ITEMS)),
		1,
		100,
	)
	var components: Array[Dictionary] = []
	for component: Component in _components_for(entity):
		components.append(_component_snapshot(component, include_private, max_items))

	var outgoing_count: int = 0
	for outgoing_relationship: Relationship in entity.relationships:
		if outgoing_relationship != null:
			outgoing_count += 1

	var incoming_count: int = 0
	for candidate: Entity in _entities_from_source(source):
		if not is_instance_valid(candidate):
			continue
		for candidate_relationship: Relationship in candidate.relationships:
			if candidate_relationship != null and candidate_relationship.target == entity:
				incoming_count += 1

	return {
		"data": {
			"ok": true,
			"source": source.get("source", "unknown"),
			"scene": source.get("scene", ""),
			"entity": _entity_summary(entity),
			"components": components,
			"relationships": {
				"outgoing": outgoing_count,
				"incoming": incoming_count,
			},
			"runtime_note": _runtime_note(source),
		},
	}


## Inspects outgoing/incoming relationships of one uniquely selected entity.
func relationships_inspect(params: Dictionary, _ctx: McpCallContext) -> Dictionary:
	var runtime_result: Dictionary = _runtime_request("relationships_inspect", params, _ctx)
	if not runtime_result.is_empty():
		return runtime_result

	var source: Dictionary = _entity_source()
	var entities: Array[Entity] = _entities_from_source(source)
	var resolution: Dictionary = _resolve_entity(params, entities)
	if not resolution.get("ok", false):
		return {"data": resolution}

	var entity: Entity = resolution["entity"] as Entity
	var relation_filter: String = String(params.get("relation", "")).strip_edges().to_lower()
	var direction: String = String(params.get("direction", "both"))
	if direction not in ["both", "outgoing", "incoming"]:
		return {"ok": false, "error": "direction must be both, outgoing, or incoming"}
	var limit: int = clampi(int(params.get("limit", DEFAULT_LIMIT)), 1, 200)
	var rows: Array[Dictionary] = []

	if direction == "both" or direction == "outgoing":
		for outgoing_relationship: Relationship in entity.relationships:
			if outgoing_relationship == null or not _relation_matches(outgoing_relationship, relation_filter):
				continue
			rows.append(_relationship_snapshot(entity, outgoing_relationship, "outgoing"))
			if rows.size() >= limit:
				break

	if rows.size() < limit and (direction == "both" or direction == "incoming"):
		for source_entity: Entity in entities:
			if not is_instance_valid(source_entity):
				continue
			for incoming_relationship: Relationship in source_entity.relationships:
				if incoming_relationship == null or incoming_relationship.target != entity:
					continue
				if not _relation_matches(incoming_relationship, relation_filter):
					continue
				rows.append(_relationship_snapshot(source_entity, incoming_relationship, "incoming"))
				if rows.size() >= limit:
					break
			if rows.size() >= limit:
				break

	return {
		"data": {
			"ok": true,
			"source": source.get("source", "unknown"),
			"scene": source.get("scene", ""),
			"entity": _entity_summary(entity),
			"relationships": rows,
			"returned": rows.size(),
			"limit": limit,
			"runtime_note": _runtime_note(source),
		},
	}

#endregion


#region Runtime routing

func _runtime_request(
	operation: String,
	params: Dictionary,
	ctx: McpCallContext,
) -> Dictionary:
	var source_mode: String = String(params.get("source", "auto")).strip_edges().to_lower()
	if source_mode not in ["auto", "runtime", "editor"]:
		return {
			"data": {
				"ok": false,
				"error": "source must be auto, runtime, or editor",
			},
		}
	if source_mode == "editor":
		return {}

	var bridge: PvzAiDebuggerBridge = PvzAiDebuggerBridge.get_instance()
	if bridge != null and bridge.runtime_ready():
		if bridge.request_runtime(operation, params, ctx):
			return McpDispatcher.DEFERRED_RESPONSE

	if source_mode == "runtime":
		return {
			"data": {
				"ok": false,
				"error": "No running game is connected to the PVZ runtime inspection bridge.",
			},
		}
	return {}

#endregion


#region Entity discovery

func _entity_source() -> Dictionary:
	if is_instance_valid(ECS.world) and not ECS.world.entities.is_empty():
		var world_entities: Array[Entity] = []
		for entity: Entity in ECS.world.entities:
			if is_instance_valid(entity):
				world_entities.append(entity)
		return {
			"source": "editor_gecs_world",
			"scene": _edited_scene_path(),
			"entities": world_entities,
		}

	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return {
			"source": "none",
			"scene": "",
			"entities": [],
		}

	var scene_entities: Array[Entity] = []
	if root is Entity:
		scene_entities.append(root as Entity)
	for node: Node in root.find_children("*", "", true, false):
		if node is Entity:
			scene_entities.append(node as Entity)

	return {
		"source": "edited_scene",
		"scene": String(root.scene_file_path),
		"entities": scene_entities,
	}


func _entities_from_source(source: Dictionary) -> Array[Entity]:
	var result: Array[Entity] = []
	var raw_entities: Variant = source.get("entities", [])
	if not (raw_entities is Array):
		return result
	for value: Variant in raw_entities:
		var entity: Entity = value as Entity
		if entity != null:
			result.append(entity)
	return result


func _resolve_entity(params: Dictionary, entities: Array[Entity]) -> Dictionary:
	var entity_id: String = String(params.get("entity_id", "")).strip_edges()
	var node_path: String = String(params.get("node_path", "")).strip_edges()
	var entity_name: String = String(params.get("name", "")).strip_edges()
	if entity_id.is_empty() and node_path.is_empty() and entity_name.is_empty():
		return {
			"ok": false,
			"error": "Provide entity_id, node_path, or name.",
		}

	var matches: Array[Entity] = []
	for entity: Entity in entities:
		if not is_instance_valid(entity):
			continue
		if not entity_id.is_empty() and str(entity.id) != entity_id:
			continue
		if not node_path.is_empty() and String(entity.get_path()) != node_path:
			continue
		if not entity_name.is_empty() and String(entity.name) != entity_name:
			continue
		matches.append(entity)

	if matches.is_empty():
		return {
			"ok": false,
			"error": "No matching Entity found in the editor-side GECS world/edited scene.",
		}
	if matches.size() > 1:
		var candidates: Array[Dictionary] = []
		var candidate_limit: int = mini(matches.size(), 20)
		for index: int in range(candidate_limit):
			candidates.append(_entity_summary(matches[index]))
		return {
			"ok": false,
			"error": "Entity selector is ambiguous; provide entity_id or node_path.",
			"matches": candidates,
		}

	return {
		"ok": true,
		"entity": matches[0],
	}


func _edited_scene_path() -> String:
	var root: Node = EditorInterface.get_edited_scene_root()
	return String(root.scene_file_path) if root != null else ""


func _runtime_note(source: Dictionary) -> String:
	if source.get("source", "") == "none":
		return "No editor-side GECS world or edited scene is available."
	return "Custom tools execute in the Godot Editor process; this is editor-side state, not the separate running-game ECS world."

#endregion


#region Entity and relationship snapshots

func _entity_summary(entity: Entity) -> Dictionary:
	var component_names: Array[String] = []
	for component: Component in _components_for(entity):
		component_names.append(_object_type(component))
	component_names.sort()

	return {
		"id": str(entity.id),
		"name": String(entity.name),
		"class_name": _object_type(entity),
		"node_path": String(entity.get_path()),
		"scene_file_path": String(entity.scene_file_path),
		"components": component_names,
		"relationship_count": entity.relationships.size(),
	}


func _components_for(entity: Entity) -> Array[Component]:
	var result: Array[Component] = []
	var seen: Dictionary = {}

	for runtime_value: Variant in entity.components.values():
		var runtime_component: Component = runtime_value as Component
		if runtime_component == null:
			continue
		var runtime_key: int = runtime_component.get_instance_id()
		if not seen.has(runtime_key):
			seen[runtime_key] = true
			result.append(runtime_component)

	for resource_value: Variant in entity.component_resources:
		var resource_component: Component = resource_value as Component
		if resource_component == null:
			continue
		var resource_key: int = resource_component.get_instance_id()
		if not seen.has(resource_key):
			seen[resource_key] = true
			result.append(resource_component)

	return result


func _component_snapshot(
	component: Component,
	include_private: bool,
	max_items: int,
) -> Dictionary:
	var properties: Dictionary = {}
	for info: Dictionary in component.get_property_list():
		var usage: int = int(info.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name: String = String(info.get("name", ""))
		if property_name.is_empty():
			continue
		if not include_private and property_name.begins_with("_"):
			continue
		properties[property_name] = _json_value(component.get(property_name), 0, max_items)

	return {
		"class_name": _object_type(component),
		"resource_path": String(component.resource_path),
		"properties": properties,
	}


func _relationship_snapshot(
	source_entity: Entity,
	relationship: Relationship,
	direction: String,
) -> Dictionary:
	return {
		"direction": direction,
		"source": _entity_ref(source_entity),
		"relation": {
			"class_name": _object_type(relationship.relation),
			"properties": _component_properties(relationship.relation),
		},
		"target": _entity_ref(relationship.target as Entity),
	}


func _component_properties(component: Component) -> Dictionary:
	if component == null:
		return {}
	var result: Dictionary = {}
	for info: Dictionary in component.get_property_list():
		var usage: int = int(info.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var property_name: String = String(info.get("name", ""))
		if property_name.begins_with("_"):
			continue
		result[property_name] = _json_value(component.get(property_name), 0, 10)
	return result


func _entity_ref(entity: Entity) -> Variant:
	if not is_instance_valid(entity):
		return null
	return {
		"id": str(entity.id),
		"name": String(entity.name),
		"class_name": _object_type(entity),
		"node_path": String(entity.get_path()),
	}

#endregion


#region Filtering and serialization

func _entity_has_component_name(entity: Entity, filter_text: String) -> bool:
	for component: Component in _components_for(entity):
		if _object_type(component).to_lower().contains(filter_text):
			return true
	return false


func _entity_matches_query(summary: Dictionary, query: String) -> bool:
	return (
		String(summary["id"]).to_lower().contains(query)
		or String(summary["name"]).to_lower().contains(query)
		or String(summary["class_name"]).to_lower().contains(query)
		or String(summary["node_path"]).to_lower().contains(query)
	)


func _relation_matches(relationship: Relationship, filter_text: String) -> bool:
	return filter_text.is_empty() or _object_type(relationship.relation).to_lower().contains(filter_text)


func _object_type(value: Object) -> String:
	if value == null:
		return ""
	var script: Script = value.get_script() as Script
	if script != null:
		var global_name: StringName = script.get_global_name()
		if not global_name.is_empty():
			return String(global_name)
	return value.get_class()


func _json_value(value: Variant, depth: int, max_items: int) -> Variant:
	if depth > MAX_VALUE_DEPTH:
		return "<max-depth>"

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			return {"x": vector2_value.x, "y": vector2_value.y}
		TYPE_VECTOR3:
			var vector3_value: Vector3 = value
			return {"x": vector3_value.x, "y": vector3_value.y, "z": vector3_value.z}
		TYPE_VECTOR4:
			var vector4_value: Vector4 = value
			return {
				"x": vector4_value.x,
				"y": vector4_value.y,
				"z": vector4_value.z,
				"w": vector4_value.w,
			}
		TYPE_COLOR:
			var color_value: Color = value
			return color_value.to_html(true)
		TYPE_NODE_PATH:
			return String(value)
		TYPE_ARRAY:
			var array_value: Array = value
			var array_result: Array = []
			for index: int in range(mini(array_value.size(), max_items)):
				array_result.append(_json_value(array_value[index], depth + 1, max_items))
			if array_value.size() > max_items:
				array_result.append("<%d more>" % (array_value.size() - max_items))
			return array_result
		TYPE_DICTIONARY:
			var dictionary_value: Dictionary = value
			var dictionary_result: Dictionary = {}
			var keys: Array = dictionary_value.keys()
			for index: int in range(mini(keys.size(), max_items)):
				var key: Variant = keys[index]
				dictionary_result[str(key)] = _json_value(
					dictionary_value[key],
					depth + 1,
					max_items,
				)
			if keys.size() > max_items:
				dictionary_result["_truncated"] = keys.size() - max_items
			return dictionary_result
		TYPE_OBJECT:
			var object_value: Object = value as Object
			if object_value == null:
				return null
			if object_value is Entity:
				return _entity_ref(object_value as Entity)
			if object_value is Node:
				var node_value: Node = object_value as Node
				return {
					"class_name": _object_type(node_value),
					"name": String(node_value.name),
					"node_path": String(node_value.get_path()),
				}
			if object_value is Resource:
				var resource_value: Resource = object_value as Resource
				return {
					"class_name": _object_type(resource_value),
					"resource_path": String(resource_value.resource_path),
				}
			return {"class_name": _object_type(object_value)}
		_:
			return str(value)


func _increment(counts: Dictionary, key: String) -> void:
	var normalized: String = key if not key.is_empty() else "<unknown>"
	counts[normalized] = int(counts.get(normalized, 0)) + 1


func _rank_counts(counts: Dictionary, limit: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for key: Variant in counts:
		rows.append({
			"name": String(key),
			"count": int(counts[key]),
		})
	rows.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_count: int = int(left["count"])
			var right_count: int = int(right["count"])
			if left_count == right_count:
				return String(left["name"]) < String(right["name"])
			return left_count > right_count
	)
	var ranked: Array[Dictionary] = []
	var ranked_limit: int = mini(rows.size(), limit)
	for index: int in range(ranked_limit):
		ranked.append(rows[index])
	return ranked

#endregion
