extends GutTest
## Non-editor safety contracts for the bounded native Inspector regression tool.

const _TOOL: Script = preload("res://addons/pvz_ai_tools/editor_traits_signal_tool.gd")
const _STYLE_TOOL: Script = preload("res://addons/pvz_ai_tools/gdscript_style_tool.gd")
const _BATCH_TOOL: Script = preload("res://addons/pvz_ai_tools/style_script_validation_tool.gd")


#region Invocation safety
func test_rejects_parameters_before_touching_editor_state() -> void:
	var handler: RefCounted = _TOOL.new() as RefCounted
	var result: Dictionary = handler.call("inspect", { "script": "unexpected" }, null)
	assert_true(result.has("error"))
	assert_eq(handler.call("quiesce_for_script_swap"), { "ok": true })


func test_busy_handler_rejects_overlap_and_blocks_hot_swap() -> void:
	var handler: RefCounted = _TOOL.new() as RefCounted
	handler.set("_busy", true)
	var result: Dictionary = handler.call("inspect", { }, null)
	assert_true(result.has("error"))
	assert_eq(handler.call("quiesce_for_script_swap"), { "ok": false })
	handler.set("_busy", false)
	assert_eq(handler.call("quiesce_for_script_swap"), { "ok": true })


func test_style_settings_reject_unknown_keys_before_editor_or_process_access() -> void:
	var handler: RefCounted = _STYLE_TOOL.new() as RefCounted
	var result: Dictionary = handler.call("configure", { "setting": "arbitrary" }, null)
	assert_true(result.has("error"))


func test_style_settings_reject_arbitrary_actions() -> void:
	var handler: RefCounted = _STYLE_TOOL.new() as RefCounted
	var result: Dictionary = handler.call("configure", { "action": "format_all" }, null)
	assert_true(result.has("error"))


func test_batch_diagnostics_reject_arbitrary_paths_and_unbounded_work() -> void:
	var handler: RefCounted = _BATCH_TOOL.new() as RefCounted
	var arbitrary: Dictionary = handler.call("inspect", { "path": "res://project.godot" }, null)
	assert_true(arbitrary.has("error"))
	var unbounded: Dictionary = handler.call("inspect", { "task": "61", "limit": 10000 }, null)
	assert_true(unbounded.has("error"))


func test_batch_diagnostics_compile_native_paths_without_instantiating() -> void:
	var handler: RefCounted = _BATCH_TOOL.new() as RefCounted
	var response: Dictionary = handler.call("inspect", { "task": "61", "limit": 1 }, null)
	var data: Dictionary = response.get("data", { })
	var reports: Array = data.get("reports", [])
	assert_eq(data.get("scripts_instantiated"), 0)
	assert_eq(reports.size(), 1)
	assert_eq(reports[0].get("error_code"), OK)
	assert_eq(reports[0].get("diagnostics_status"), "checked")
	assert_eq(reports[0].get("diagnostics"), [])


func test_batch_diagnostics_accept_integral_json_numbers_and_reject_fractional_limits() -> void:
	var handler: RefCounted = _BATCH_TOOL.new() as RefCounted
	var parsed: Dictionary = JSON.parse_string('{"task":"61","offset":0,"limit":1}')
	var accepted: Dictionary = handler.call("inspect", parsed, null)
	assert_false(accepted.has("error"))
	assert_eq(accepted.get("data", { }).get("reports", []).size(), 1)
	var fractional: Dictionary = handler.call("inspect", { "task": "61", "limit": 1.5 }, null)
	assert_eq(fractional.get("error", { }).get("code"), "INVALID_PARAMS")
#endregion
