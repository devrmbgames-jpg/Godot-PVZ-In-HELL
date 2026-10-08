extends SceneTree
## Headless changed-file compilation; isolated project processes for GUT fixture scripts.

#region Parser entry
func _initialize() -> void:
	call_deferred("_parse_selected_scripts")


func _parse_selected_scripts() -> void:
	var selected_paths: PackedStringArray = OS.get_cmdline_user_args()
	if selected_paths.is_empty():
		push_error("Supply project-owned .gd paths after --")
		quit(2)
		return

	var isolated_script: bool = selected_paths[0] == "--isolated-script"
	if isolated_script:
		selected_paths.remove_at(0)
		if selected_paths.size() != 1:
			push_error("Isolated compilation requires exactly one project-owned script")
			quit(2)
			return

	var failures: int = 0
	for selected_path: String in selected_paths:
		var resource_path: String = selected_path.replace("\\", "/")
		if not resource_path.begins_with("res://"):
			resource_path = "res://" + resource_path
		if not resource_path.ends_with(".gd") or resource_path.begins_with("res://addons/"):
			push_error("Parser selection must be a project-owned .gd: " + resource_path)
			failures += 1
			continue

		# Each fixture requires project autoloads but not another fixture's GUI/script graph.
		if resource_path.begins_with("res://tests/gut/") and not isolated_script:
			if not _parse_isolated_script(resource_path):
				failures += 1
			continue

		var selected_script: GDScript = load(resource_path) as GDScript
		if selected_script == null or (
			not selected_script.can_instantiate() and not selected_script.is_abstract()
		):
			failures += 1
			continue
		# This helper runs in a fresh process: loading compiles each dependency once.
		# Recompiling an already-loaded base can retain old subclass/resource graphs.

	print("Changed-script parser: %s (%d files, %d failures)" % [
		"PASS" if failures == 0 else "FAIL", selected_paths.size(), failures
	])
	quit(0 if failures == 0 else 1)

func _parse_isolated_script(resource_path: String) -> bool:
	var compiler_output: Array[String] = []
	var parser_script: GDScript = get_script() as GDScript
	var check_arguments: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", parser_script.resource_path, "--", "--isolated-script", resource_path,
	])
	var check_exit_code: int = OS.execute(
		OS.get_executable_path(), check_arguments, compiler_output, true,
	)
	var diagnostic_failure: bool = false
	for output: String in compiler_output:
		if "ERROR:" in output or "WARNING:" in output or "SCRIPT ERROR" in output:
			diagnostic_failure = true
			print(output)
	if check_exit_code != 0 or diagnostic_failure:
		push_error("Isolated script compilation failed: " + resource_path)
		return false
	return true
#endregion
