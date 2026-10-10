@tool
extends RefCounted
## Validates path-bound scripts from a fixed style task; no instances or authored data writes.

const _ERROR_CODES: Script = preload("res://addons/godot_ai/utils/error_codes.gd")
const _MANIFEST: String = "res://utils/gdscript_style_manifest.json"
const _LOGGER: Script = preload("res://addons/godot_ai/runtime/validation_logger.gd")
const _CAPTURE: Script = preload("res://addons/godot_ai/utils/diagnostics_capture.gd")


#region Bounded diagnostics
## Calls retain no requests, instances or editor resources.
func quiesce_for_script_swap() -> Dictionary:
	return { "ok": true }


## Compile at most 25 manifest scripts using their native resource paths.
func inspect(params: Dictionary, _context: McpCallContext) -> Dictionary:
	for key: Variant in params:
		if key not in ["task", "offset", "limit"]:
			return _ERROR_CODES.make(_ERROR_CODES.INVALID_PARAMS, "Unknown diagnostics parameter.")
	if not params.get("task") is String:
		return _ERROR_CODES.make(_ERROR_CODES.INVALID_PARAMS, "Task must be a string selector.")
	for key: String in ["offset", "limit"]:
		if not params.has(key):
			continue
		var value: Variant = params[key]
		if not (value is int or value is float):
			return _ERROR_CODES.make(_ERROR_CODES.INVALID_PARAMS, "Integer pagination required.")
		# Native JSON numbers may be floats even for an integer schema.
		if not is_finite(float(value)) or float(value) != floor(float(value)):
			return _ERROR_CODES.make(_ERROR_CODES.INVALID_PARAMS, "Integer pagination required.")
	var task: String = String(params.get("task", ""))
	var offset: int = int(params.get("offset", 0))
	var limit: int = int(params.get("limit", 25))
	if task not in ["61", "62", "63", "64", "65"] or offset < 0 or limit < 1 or limit > 25:
		return _ERROR_CODES.make(
			_ERROR_CODES.INVALID_PARAMS,
			"Expected task61–65, nonnegative offset and limit1–25.",
		)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_MANIFEST))
	if not parsed is Dictionary:
		return _ERROR_CODES.make(_ERROR_CODES.INVALID_PARAMS, "Missing style ownership manifest.")
	var manifest: Dictionary = parsed
	var tasks: Dictionary = manifest.get("tasks", { })
	var paths: Array = tasks.get(task, [])
	var reports: Array[Dictionary] = []
	for index: int in range(offset, mini(offset + limit, paths.size())):
		var path: String = "res://" + String(paths[index])
		if not _owned_path(path):
			return _ERROR_CODES.make(
				_ERROR_CODES.INVALID_PARAMS,
				"Manifest contains an out-of-scope path.",
			)
		reports.append(_compile_path(path))
	return {
		"data": {
			"task": task,
			"total": paths.size(),
			"offset": offset,
			"reports": reports,
			"next_offset": mini(offset + limit, paths.size()),
			"scripts_instantiated": 0,
		}
	}
#endregion


#region Path-bound compilation
func _owned_path(path: String) -> bool:
	return (
		path.ends_with(".gd") and not ".." in path
		and (
			path.begins_with("res://content/") or path.begins_with("res://tests/")
			or path.begins_with("res://utils/") or path.begins_with("res://addons/pvz_ai_tools/")
			or path.begins_with("res://addons/project_entity_traits/")
		)
	)


func _compile_path(path: String) -> Dictionary:
	var handler_script: GDScript = get_script() as GDScript
	if path == handler_script.resource_path:
		# Godot reuses a loaded script even with CACHE_MODE_IGNORE. Compiling the
		# executing handler invalidates its own bytecode. Its existing compiled
		# instance proves only the exact source currently loaded by the registry.
		var current_source: String = FileAccess.get_file_as_string(path).replace("\r\n", "\n")
		var source_matches: bool = (
			handler_script.source_code.replace("\r\n", "\n") == current_source
		)
		return {
			"path": path,
			"error_code": OK if source_matches and handler_script.can_instantiate() else ERR_BUSY,
			"diagnostics_status": "checked" if source_matches else "unavailable",
			"diagnostics": [],
			"validation_mode": "compiled_handler" if source_matches else "handler_reload_required",
		}
	var buffer: McpEditorLogBuffer = McpEditorLogBuffer.new()
	var logger: Logger = _LOGGER.new(buffer) as Logger
	var captured: Dictionary = _CAPTURE.capture_this_file(
		buffer,
		path,
		func() -> Dictionary:
			OS.add_logger(logger)
			var script: GDScript = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			# Explicit reload reports compilation independently of editor instantiation
			# restrictions on non-tool gameplay scripts.
			var result: Error = script.reload(true) if script != null else ERR_CANT_OPEN
			OS.remove_logger(logger)
			return { "error_code": result },
	)
	return {
		"path": path,
		"error_code": captured.action.get("error_code", FAILED),
		"diagnostics_status": captured.diagnostics_status,
		"diagnostics": captured.diagnostics,
	}
#endregion
