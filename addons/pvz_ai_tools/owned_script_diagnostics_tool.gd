@tool
extends "res://addons/pvz_ai_tools/style_script_validation_tool.gd"
## Compiles up to eight existing project-owned scripts at their real paths; no gameplay instances.

const MAX_PATHS: int = 8


#region Bounded owned-script diagnostics
func inspect_paths(params: Dictionary, _context: McpCallContext) -> Dictionary:
	if params.size() != 1 or not params.get("paths") is Array:
		return _ERROR_CODES.make(_ERROR_CODES.INVALID_PARAMS, "Expected only a paths array.")
	var requested: Array = params.paths
	if requested.is_empty() or requested.size() > MAX_PATHS:
		return _ERROR_CODES.make(_ERROR_CODES.INVALID_PARAMS, "Expected one through eight scripts.")

	var paths: Array[String] = []
	for value: Variant in requested:
		if not value is String:
			return _ERROR_CODES.make(_ERROR_CODES.INVALID_PARAMS, "Script paths must be strings.")
		var path: String = value
		if (
			not _owned_path(path) or path.contains("\\")
			or path.simplify_path() != path or path.trim_prefix("res://").contains(":")
			or not FileAccess.file_exists(path) or paths.has(path)
		):
			return _ERROR_CODES.make(_ERROR_CODES.INVALID_PARAMS, "Invalid owned script path.")
		paths.append(path)

	var reports: Array[Dictionary] = []
	for path: String in paths:
		reports.append(_inspect_owned(path))
	return { "data": { "reports": reports, "scripts_instantiated": 0 } }


func _inspect_owned(path: String) -> Dictionary:
	# Reloading any executing base invalidates inherited bytecode, not just this child handler.
	var active_script: GDScript = get_script() as GDScript
	while active_script != null:
		if active_script.resource_path == path:
			var source: String = FileAccess.get_file_as_string(path).replace("\r\n", "\n")
			var current: bool = active_script.source_code.replace("\r\n", "\n") == source
			return {
				"path": path,
				"error_code": OK if current and active_script.can_instantiate() else ERR_BUSY,
				"diagnostics_status": "checked" if current else "unavailable",
				"diagnostics": [],
				"validation_mode": "compiled_handler" if current else "handler_reload_required",
			}
		active_script = active_script.get_base_script() as GDScript
	return _compile_path(path)
#endregion
