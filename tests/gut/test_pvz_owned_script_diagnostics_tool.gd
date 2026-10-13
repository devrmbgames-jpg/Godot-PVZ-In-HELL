extends GutTest
## Owned-script diagnostics preflight whole requests and never reload executing handler bytecode.

const TOOL: Script = preload("res://addons/pvz_ai_tools/owned_script_diagnostics_tool.gd")


#region Request boundaries and native compilation
func test_preflight_rejects_escaping_third_party_missing_duplicate_and_unbounded_paths() -> void:
	var handler: RefCounted = TOOL.new()
	var valid: String = "res://content/domains/npc/contracts/npc_sign_text_request.gd"
	var missing: String = "res://content/".path_join("missing_script.gd")
	for paths: Array in [
		[],
		["res://addons/gecs/ecs/entity.gd"],
		["res://content/../addons/gecs/ecs/entity.gd"],
		["res://content\\domains\\npc\\contracts\\npc_sign_text_request.gd"],
		[missing],
		[valid, valid],
		[1],
		[valid, valid, valid, valid, valid, valid, valid, valid, valid],
	]:
		var result: Dictionary = handler.inspect_paths({ "paths": paths }, null)
		assert_true(result.has("error"))
		assert_false(result.has("data"))
	assert_true(handler.inspect_paths({ "paths": [valid], "extra": true }, null).has("error"))
	assert_true(handler.inspect_paths({ "paths": valid }, null).has("error"))


func test_native_compilation_preserves_files_nodes_and_returns_checked_reports() -> void:
	var handler: RefCounted = TOOL.new()
	var paths: Array[String] = [
		"res://content/domains/npc/contracts/npc_sign_text_request.gd",
		"res://content/domains/npc/presentation/npc_signboard.gd",
	]
	var checksums: Array[String] = []
	for path: String in paths:
		checksums.append(FileAccess.get_md5(path))
	var node_count: int = get_tree().root.get_child_count()
	var result: Dictionary = handler.inspect_paths({ "paths": paths }, null)
	assert_false(result.has("error"))
	var data: Dictionary = result.data
	assert_eq(data.scripts_instantiated, 0)
	var reports: Array = data.reports
	assert_eq(reports.size(), 2)
	for index: int in paths.size():
		var report: Dictionary = reports[index]
		assert_eq(report.path, paths[index])
		assert_eq(report.error_code, OK)
		assert_eq(report.diagnostics_status, "checked")
		assert_eq(report.diagnostics, [])
		assert_eq(FileAccess.get_md5(paths[index]), checksums[index])
	assert_eq(get_tree().root.get_child_count(), node_count)


func test_executing_handler_and_parent_report_loaded_source_without_reloading_it() -> void:
	var handler: RefCounted = TOOL.new()
	var result: Dictionary = handler.inspect_paths(
		{
			"paths": [
				"res://addons/pvz_ai_tools/owned_script_diagnostics_tool.gd",
				"res://addons/pvz_ai_tools/style_script_validation_tool.gd",
			],
		},
		null,
	)
	assert_false(result.has("error"))
	for report: Dictionary in result.data.reports:
		assert_eq(report.error_code, OK)
		assert_eq(report.diagnostics_status, "checked")
		assert_eq(report.validation_mode, "compiled_handler")
	assert_eq(handler.quiesce_for_script_swap(), { "ok": true })
#endregion
