## Registers compact, read-only PVZ/GECS inspection tools with Godot AI MCP.
@tool
extends EditorPlugin

const SOURCE_CFG: String = "res://addons/pvz_ai_tools/plugin.cfg"
const HANDLER_PATH: String = "res://addons/pvz_ai_tools/gecs_tools.gd"
const RETRY_SECONDS: float = 1.0
const DebuggerBridgeScript := preload("res://addons/pvz_ai_tools/debugger_bridge.gd")

var _registry: McpToolRegistry = null
var _debugger_bridge: PvzAiDebuggerBridge = null
var _retry_elapsed: float = 0.0
var _registered: bool = false


#region Lifecycle

func _enter_tree() -> void:
	_debugger_bridge = DebuggerBridgeScript.new() as PvzAiDebuggerBridge
	if _debugger_bridge != null:
		add_debugger_plugin(_debugger_bridge)
	set_process(true)
	call_deferred("_refresh_registry")


func _exit_tree() -> void:
	var registry: McpToolRegistry = McpToolRegistry.get_instance()
	if registry != null:
		registry.unregister_source(SOURCE_CFG)
	_disconnect_registry()

	if _debugger_bridge != null:
		_debugger_bridge.shutdown()
		remove_debugger_plugin(_debugger_bridge)
		_debugger_bridge = null
	_registered = false


func _process(delta: float) -> void:
	if _debugger_bridge != null:
		_debugger_bridge.expire_pending()

	_retry_elapsed += delta
	if _retry_elapsed < RETRY_SECONDS:
		return
	_retry_elapsed = 0.0
	_refresh_registry()

#endregion


#region Registration

func _refresh_registry() -> void:
	var current: McpToolRegistry = McpToolRegistry.get_instance()
	if current == _registry and is_instance_valid(_registry):
		if _registry.is_ready() and not _registered:
			_register_tools()
		return

	_disconnect_registry()
	_registry = current
	_registered = false
	if _registry == null:
		return
	if not _registry.registry_ready.is_connected(_on_registry_ready):
		_registry.registry_ready.connect(_on_registry_ready)
	if _registry.is_ready():
		_register_tools()


func _disconnect_registry() -> void:
	if is_instance_valid(_registry) and _registry.registry_ready.is_connected(_on_registry_ready):
		_registry.registry_ready.disconnect(_on_registry_ready)
	_registry = null


func _on_registry_ready() -> void:
	_registered = false
	_register_tools()


func _register_tools() -> void:
	if not is_instance_valid(_registry):
		return

	var specs: Array[McpCustomToolSpec] = [
		_make_spec(
			"pvz_gecs_world_summary",
			(
				"Summarize PVZ GECS entities, component types and "
				+ "relationships from runtime when available or the edited " + "scene."
			),
			&"world_summary",
			{
				"type": "object",
				"properties": {
					"source": _source_property(),
					"max_types": { "type": "integer", "minimum": 1, "maximum": 100, "default": 30 },
				},
				"additionalProperties": false,
			},
		),
		_make_spec(
			"pvz_gecs_find_entities",
			(
				"Find PVZ GECS entities by id/name/path/class/component "
				+ "without dumping the full SceneTree."
			),
			&"find_entities",
			{
				"type": "object",
				"properties": {
					"source": _source_property(),
					"query": { "type": "string", "default": "" },
					"class_name": { "type": "string", "default": "" },
					"component": { "type": "string", "default": "" },
					"limit": { "type": "integer", "minimum": 1, "maximum": 200, "default": 50 },
				},
				"additionalProperties": false,
			},
		),
		_make_spec(
			"pvz_gecs_entity_inspect",
			(
				"Inspect one PVZ GECS entity, including compact component "
				+ "values and relationship counts."
			),
			&"entity_inspect",
			{
				"type": "object",
				"properties": {
					"source": _source_property(),
					"entity_id": { "type": "string", "default": "" },
					"node_path": { "type": "string", "default": "" },
					"name": { "type": "string", "default": "" },
					"include_private": { "type": "boolean", "default": false },
					"max_collection_items": {
						"type": "integer",
						"minimum": 1,
						"maximum": 100,
						"default": 20,
					},
				},
				"additionalProperties": false,
			},
		),
		_make_spec(
			"pvz_gecs_relationships",
			(
				"Inspect outgoing and incoming PVZ GECS relationships for one "
				+ "entity with optional relation filtering."
			),
			&"relationships_inspect",
			{
				"type": "object",
				"properties": {
					"source": _source_property(),
					"entity_id": { "type": "string", "default": "" },
					"node_path": { "type": "string", "default": "" },
					"name": { "type": "string", "default": "" },
					"relation": { "type": "string", "default": "" },
					"direction": {
						"type": "string",
						"enum": ["both", "outgoing", "incoming"],
						"default": "both",
					},
					"limit": { "type": "integer", "minimum": 1, "maximum": 200, "default": 50 },
				},
				"additionalProperties": false,
			},
		),
		_editor_ownership_spec(),
		_editor_traits_signal_spec(),
		_gdscript_style_spec(),
		_style_script_validation_spec(),
		_translation_sources_spec(),
		_behavior_tree_authoring_spec(),
		_npc_archetype_cache_spec(),
		_npc_archetype_resave_spec(),
	]

	_registered = _registry.batch_register(specs)
	if not _registered:
		push_warning(
			"PVZ Godot AI Tools: custom tool registration failed; see Godot AI diagnostics."
		)


func _make_spec(
	tool_name: String,
	description: String,
	method: StringName,
	schema: Dictionary,
) -> McpCustomToolSpec:
	var spec: McpCustomToolSpec = McpCustomToolSpec.new()
	spec.name = tool_name
	spec.description = description
	spec.params_schema = schema
	spec.script_path = HANDLER_PATH
	spec.method = method
	spec.source_path = SOURCE_CFG
	spec.source = "PVZ Godot AI Tools"
	spec.promoted = true
	spec.requires_writable = false
	spec.undoable = false
	spec.deferred = true
	spec.timeout_ms = 7000
	return spec


## This editor-only query is synchronous, read-only and never changes ownership.
func _editor_ownership_spec() -> McpCustomToolSpec:
	var spec: McpCustomToolSpec = McpCustomToolSpec.new()
	spec.name = "pvz_editor_ownership"
	spec.description = (
		"List currently open and unsaved Godot Editor scenes before " + "authoring, reload or save."
	)
	spec.params_schema = { "type": "object", "properties": { }, "additionalProperties": false }
	spec.script_path = "res://addons/pvz_ai_tools/editor_ownership_tool.gd"
	spec.method = &"inspect"
	spec.source_path = SOURCE_CFG
	spec.source = "PVZ Godot AI Tools"
	spec.promoted = true
	spec.requires_writable = false
	spec.undoable = false
	spec.deferred = false
	spec.timeout_ms = 3000
	return spec


## Disposable Inspector navigation check; no authored-content or undo-history mutation.
func _editor_traits_signal_spec() -> McpCustomToolSpec:
	var spec: McpCustomToolSpec = McpCustomToolSpec.new()
	spec.name = "pvz_editor_traits_signal_check"
	spec.description = (
		"Check direct Traits Inspector signal lifetime with temporary controls "
		+ "and restore the current Inspector."
	)
	spec.params_schema = { "type": "object", "properties": { }, "additionalProperties": false }
	spec.script_path = "res://addons/pvz_ai_tools/editor_traits_signal_tool.gd"
	spec.method = &"inspect"
	spec.source_path = SOURCE_CFG
	spec.source = "PVZ Godot AI Tools"
	spec.requires_writable = true
	spec.undoable = false
	spec.deferred = true
	spec.timeout_ms = 7000
	return spec


## Native, fixed EditorSettings configuration for the pinned project formatter.
func _gdscript_style_spec() -> McpCustomToolSpec:
	var spec: McpCustomToolSpec = McpCustomToolSpec.new()
	spec.name = "pvz_gdscript_style_settings"
	spec.description = "Inspect or apply the project's pinned native GDQuest formatter settings."
	spec.params_schema = {
		"type": "object",
		"properties": { "action": { "type": "string", "enum": ["inspect", "apply"] } },
		"additionalProperties": false,
	}
	spec.script_path = "res://addons/pvz_ai_tools/gdscript_style_tool.gd"
	spec.method = &"configure"
	spec.source_path = SOURCE_CFG
	spec.source = "PVZ Godot AI Tools"
	spec.requires_writable = true
	spec.undoable = false
	return spec


## Compile fixed manifest batches with real resource paths; never instantiate gameplay.
func _style_script_validation_spec() -> McpCustomToolSpec:
	var spec: McpCustomToolSpec = McpCustomToolSpec.new()
	spec.name = "pvz_gdscript_batch_diagnostics"
	spec.description = "Compile a bounded style manifest batch using native script resource paths."
	spec.params_schema = {
		"type": "object",
		"properties": {
			"task": { "type": "string", "enum": ["61", "62", "63", "64", "65"] },
			"offset": { "type": "integer", "minimum": 0, "default": 0 },
			"limit": { "type": "integer", "minimum": 1, "maximum": 25, "default": 25 },
		},
		"required": ["task"],
		"additionalProperties": false,
	}
	spec.script_path = "res://addons/pvz_ai_tools/style_script_validation_tool.gd"
	spec.method = &"inspect"
	spec.source_path = SOURCE_CFG
	spec.source = "PVZ Godot AI Tools"
	spec.requires_writable = true
	spec.undoable = false
	spec.timeout_ms = 15000
	return spec


## Fixed native PackedStringArray cleanup; no scene, gameplay or arbitrary-setting access.
func _translation_sources_spec() -> McpCustomToolSpec:
	var spec: McpCustomToolSpec = McpCustomToolSpec.new()
	spec.name = "pvz_translation_sources"
	spec.description = "Preview/apply vanished diagnostic dialogue sources with native types."
	spec.params_schema = {
		"type": "object",
		"properties": { "action": { "type": "string", "enum": ["preview", "apply"] } },
		"required": ["action"],
		"additionalProperties": false,
	}
	spec.script_path = "res://addons/pvz_ai_tools/translation_sources_tool.gd"
	spec.method = &"configure"
	spec.source_path = SOURCE_CFG
	spec.source = "PVZ Godot AI Tools"
	spec.requires_writable = true
	spec.undoable = false
	spec.deferred = false
	return spec


func _source_property() -> Dictionary:
	return {
		"type": "string",
		"enum": ["auto", "runtime", "editor"],
		"default": "auto",
		"description": (
			"auto prefers the running game's GECS world, then falls back " + "to editor-side state."
		),
	}


## Bounded native Resource saves; existing tree edits require the captured root child order.
func _behavior_tree_authoring_spec() -> McpCustomToolSpec:
	var spec: McpCustomToolSpec = McpCustomToolSpec.new()
	spec.name = "pvz_behavior_tree_authoring"
	spec.description = "Inspect/create/replace an NPC LimboAI tree or insert a guarded subtree."
	spec.params_schema = {
		"type": "object",
		"properties": {
			"op": { "type": "string", "enum": ["inspect", "create", "replace", "insert"] },
			"path": { "type": "string" },
			"root": { "type": "object" },
			"fingerprint": { "type": "string" },
			"subtree": { "type": "string" },
			"index": { "type": "integer", "minimum": 0, "maximum": 64 },
			"name": { "type": "string" },
			"expected_children": { "type": "array", "items": { "type": "string" }, "maxItems": 64 },
		},
		"required": ["op", "path"],
		"additionalProperties": false,
	}
	spec.script_path = "res://addons/pvz_ai_tools/behavior_tree_authoring_tool.gd"
	spec.method = &"author"
	spec.source_path = SOURCE_CFG
	spec.source = "PVZ Godot AI Tools"
	spec.requires_writable = true
	spec.undoable = false
	spec.deferred = false
	return spec


## Refreshes only native saved archetype caches after checking editor ownership.
func _npc_archetype_cache_spec() -> McpCustomToolSpec:
	var spec: McpCustomToolSpec = McpCustomToolSpec.new()
	spec.name = "pvz_npc_archetype_cache_refresh"
	spec.description = "Refresh NPC archetypes and exact identity/order caches; no file writes."
	spec.params_schema = {
		"type": "object",
		"properties": {
			"paths": {
				"type": "array",
				"items": { "type": "string" },
				"minItems": 1,
				"maxItems": 16,
			},
		},
		"required": ["paths"],
		"additionalProperties": false,
	}
	spec.script_path = "res://addons/pvz_ai_tools/npc_archetype_cache_tool.gd"
	spec.method = &"refresh"
	spec.source_path = SOURCE_CFG
	spec.source = "PVZ Godot AI Tools"
	spec.requires_writable = true
	spec.undoable = false
	spec.deferred = false
	return spec


## Resaves an existing resource graph only after exact fingerprint and editor ownership checks.
func _npc_archetype_resave_spec() -> McpCustomToolSpec:
	var spec: McpCustomToolSpec = McpCustomToolSpec.new()
	spec.name = "pvz_npc_archetype_resave"
	spec.description = "Canonical native resave of up to eight fingerprinted NPC definitions."
	spec.params_schema = {
		"type": "object",
		"properties": {
			"fingerprints": { "type": "object", "maxProperties": 8 },
			"dialogue_pools": { "type": "object", "maxProperties": 8 },
			"trait_additions": { "type": "object", "maxProperties": 8 },
		},
		"required": ["fingerprints"],
		"additionalProperties": false,
	}
	spec.script_path = "res://addons/pvz_ai_tools/npc_archetype_resave_tool.gd"
	spec.method = &"resave"
	spec.source_path = SOURCE_CFG
	spec.source = "PVZ Godot AI Tools"
	spec.requires_writable = true
	spec.undoable = false
	spec.deferred = false
	return spec

#endregion
