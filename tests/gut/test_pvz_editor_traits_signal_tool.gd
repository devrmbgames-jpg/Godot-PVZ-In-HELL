extends GutTest
## Non-editor safety contracts for the bounded native Inspector regression tool.

const _TOOL: Script = preload("res://addons/pvz_ai_tools/editor_traits_signal_tool.gd")


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
#endregion
