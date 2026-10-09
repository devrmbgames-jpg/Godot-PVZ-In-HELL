extends SceneTree
## Validates a detached scene snapshot and emits JSON; no gameplay scene enters the SceneTree.


#region Detached headless entry point
func _init() -> void:
	_preview.call_deferred()


func _preview() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Expected input scene and output JSON paths")
		quit(2)
		return
	var scene_path: String = arguments[0]
	# Load after autoload registration, like the project's existing parser entry point.
	var preview_rules: GDScript = load(
		"res://content/editor/entity_authoring/entity_authoring_preview_rules.gd"
	) as GDScript
	var issues: PackedStringArray = preview_rules.call("dependency_issues", scene_path)
	var report: Dictionary = { "valid": false, "issues": issues, "actors": [] }
	if issues.is_empty():
		var scene: PackedScene = load(scene_path) as PackedScene
		if scene == null:
			report.issues = ["Input must be a loadable PackedScene"]
		else:
			var detached: Node = scene.instantiate()
			report = preview_rules.call("inspect_scene", detached)
			detached.free()
	var output: FileAccess = FileAccess.open(arguments[1], FileAccess.WRITE)
	if output == null:
		push_error("Cannot write authoring diagnostics: %s" % arguments[1])
		quit(2)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("Entity authoring: %d actors, valid=%s" % [(report.actors as Array).size(), report.valid])
	quit(0 if report.valid else 1)
#endregion
