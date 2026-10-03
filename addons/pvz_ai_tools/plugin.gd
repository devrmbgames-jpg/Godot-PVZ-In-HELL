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
			"Summarize PVZ GECS entities, component types and relationships from runtime when available or the edited scene.",
			&"world_summary",
			{
				"type": "object",
				"properties": {
					"source": _source_property(),
					"max_types": {"type": "integer", "minimum": 1, "maximum": 100, "default": 30},
				},
				"additionalProperties": false,
			},
		),
		_make_spec(
			"pvz_gecs_find_entities",
			"Find PVZ GECS entities by id/name/path/class/component without dumping the full SceneTree.",
			&"find_entities",
			{
				"type": "object",
				"properties": {
					"source": _source_property(),
					"query": {"type": "string", "default": ""},
					"class_name": {"type": "string", "default": ""},
					"component": {"type": "string", "default": ""},
					"limit": {"type": "integer", "minimum": 1, "maximum": 200, "default": 50},
				},
				"additionalProperties": false,
			},
		),
		_make_spec(
			"pvz_gecs_entity_inspect",
			"Inspect one PVZ GECS entity, including compact component values and relationship counts.",
			&"entity_inspect",
			{
				"type": "object",
				"properties": {
					"source": _source_property(),
					"entity_id": {"type": "string", "default": ""},
					"node_path": {"type": "string", "default": ""},
					"name": {"type": "string", "default": ""},
					"include_private": {"type": "boolean", "default": false},
					"max_collection_items": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20},
				},
				"additionalProperties": false,
			},
		),
		_make_spec(
			"pvz_gecs_relationships",
			"Inspect outgoing and incoming PVZ GECS relationships for one entity with optional relation filtering.",
			&"relationships_inspect",
			{
				"type": "object",
				"properties": {
					"source": _source_property(),
					"entity_id": {"type": "string", "default": ""},
					"node_path": {"type": "string", "default": ""},
					"name": {"type": "string", "default": ""},
					"relation": {"type": "string", "default": ""},
					"direction": {"type": "string", "enum": ["both", "outgoing", "incoming"], "default": "both"},
					"limit": {"type": "integer", "minimum": 1, "maximum": 200, "default": 50},
				},
				"additionalProperties": false,
			},
		),
	]

	_registered = _registry.batch_register(specs)
	if not _registered:
		push_warning("PVZ Godot AI Tools: custom tool registration failed; see Godot AI diagnostics.")


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


func _source_property() -> Dictionary:
	return {
		"type": "string",
		"enum": ["auto", "runtime", "editor"],
		"default": "auto",
		"description": "auto prefers the running game's GECS world, then falls back to editor-side state.",
	}

#endregion
