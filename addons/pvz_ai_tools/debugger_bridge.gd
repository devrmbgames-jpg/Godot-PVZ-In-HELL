@tool
## Bridges deferred PVZ custom-tool requests from the editor process to the running game.
class_name PvzAiDebuggerBridge
extends EditorDebuggerPlugin

const CAPTURE_PREFIX: String = "pvz_ai"

static var _instance: PvzAiDebuggerBridge = null

var _runtime_session_id: int = -1
var _pending: Dictionary = {}


#region Lifecycle

func _init() -> void:
	_instance = self


func _has_capture(capture: String) -> bool:
	return capture == CAPTURE_PREFIX


func _setup_session(session_id: int) -> void:
	var session: EditorDebuggerSession = get_session(session_id)
	if session == null:
		return
	var stopped_callback: Callable = Callable(self, "_on_session_stopped").bind(session_id)
	if not session.stopped.is_connected(stopped_callback):
		session.stopped.connect(stopped_callback)
	session.send_message("pvz_ai:ping", [])


func _capture(message: String, data: Array, session_id: int) -> bool:
	match message:
		"pvz_ai:hello":
			_runtime_session_id = session_id
			return true
		"pvz_ai:response":
			_handle_response(data, session_id)
			return true
	return false

#endregion


#region Public bridge API

## Returns the active bridge instance owned by the PVZ editor plugin.
static func get_instance() -> PvzAiDebuggerBridge:
	return _instance


## Returns true when the running game registered the PVZ debugger capture.
func runtime_ready() -> bool:
	if _runtime_session_id < 0:
		return false
	var session: EditorDebuggerSession = get_session(_runtime_session_id)
	return session != null and session.is_active()


## Schedules one runtime inspection request after the custom-tool handler returns deferred.
func request_runtime(
	operation: String,
	params: Dictionary,
	ctx: McpCallContext,
) -> bool:
	if ctx == null or ctx.request_id.is_empty() or not runtime_ready():
		return false
	_pending[ctx.request_id] = {
		"operation": operation,
		"params": params.duplicate(true),
		"context": ctx,
	}
	call_deferred("_send_pending", ctx.request_id)
	return true


## Returns true while at least one runtime custom-tool reply is outstanding.
func has_pending() -> bool:
	return not _pending.is_empty()


## Drops custom-tool requests whose MCP deadline has already elapsed.
func expire_pending() -> void:
	for request_key: Variant in _pending.keys():
		var request_id: String = String(request_key)
		var entry: Dictionary = _pending.get(request_id, {})
		var ctx: McpCallContext = entry.get("context") as McpCallContext
		if ctx == null or ctx.is_expired():
			_pending.erase(request_id)


## Releases singleton state and fails any still-live pending requests.
func shutdown() -> void:
	_fail_all_pending("PVZ runtime inspection bridge was unloaded.")
	_runtime_session_id = -1
	if _instance == self:
		_instance = null

#endregion


#region Request routing

func _send_pending(request_id: String) -> void:
	var entry: Dictionary = _pending.get(request_id, {})
	if entry.is_empty():
		return

	var ctx: McpCallContext = entry.get("context") as McpCallContext
	if ctx == null or ctx.is_expired():
		_pending.erase(request_id)
		return

	var session: EditorDebuggerSession = get_session(_runtime_session_id)
	if session == null or not session.is_active():
		_pending.erase(request_id)
		ctx.send_deferred({
			"data": {
				"ok": false,
				"error": "PVZ runtime bridge is not connected to an active game session.",
			},
		})
		return

	session.send_message(
		"pvz_ai:inspect",
		[
			request_id,
			String(entry.get("operation", "")),
			entry.get("params", {}) as Dictionary,
		],
	)


func _handle_response(data: Array, session_id: int) -> void:
	if session_id != _runtime_session_id or data.size() < 2:
		return
	var request_id: String = String(data[0])
	var entry: Dictionary = _pending.get(request_id, {})
	if entry.is_empty():
		return
	_pending.erase(request_id)

	var ctx: McpCallContext = entry.get("context") as McpCallContext
	if ctx == null or ctx.is_expired():
		return

	var raw_payload: Variant = data[1]
	var payload: Dictionary = {}
	if raw_payload is Dictionary:
		payload = raw_payload as Dictionary
	else:
		payload = {
			"ok": false,
			"error": "PVZ runtime bridge returned a malformed payload.",
		}
	ctx.send_deferred({"data": payload})


func _on_session_stopped(session_id: int) -> void:
	if session_id != _runtime_session_id:
		return
	_runtime_session_id = -1
	_fail_all_pending("The running game stopped before PVZ runtime inspection completed.")


func _fail_all_pending(message: String) -> void:
	for request_key: Variant in _pending.keys():
		var request_id: String = String(request_key)
		var entry: Dictionary = _pending.get(request_id, {})
		var ctx: McpCallContext = entry.get("context") as McpCallContext
		if ctx != null and not ctx.is_expired():
			ctx.send_deferred({
				"data": {
					"ok": false,
					"error": message,
				},
			})
	_pending.clear()

#endregion
