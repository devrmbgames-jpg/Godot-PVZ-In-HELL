extends SceneTree
## Headless changed-file parser with project autoloads, without loading any gameplay scene.

#region Parser entry
func _initialize() -> void:
	call_deferred("_parse_selected_scripts")


func _parse_selected_scripts() -> void:
	var selected_paths: PackedStringArray = OS.get_cmdline_user_args()
	if selected_paths.is_empty():
		push_error("Supply project-owned .gd paths after --")
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

		var selected_script: GDScript = load(resource_path) as GDScript
		if selected_script == null:
			failures += 1
			continue
		# The running parser has already compiled; reloading its live instance is forbidden.
		if selected_script == get_script():
			continue
		var reload_error: Error = selected_script.reload()
		if reload_error != OK:
			push_error("Parser failed: %s (%s)" % [resource_path, error_string(reload_error)])
			failures += 1

	print("Changed-script parser: %s (%d files, %d failures)" % [
		"PASS" if failures == 0 else "FAIL", selected_paths.size(), failures
	])
	quit(0 if failures == 0 else 1)
#endregion
