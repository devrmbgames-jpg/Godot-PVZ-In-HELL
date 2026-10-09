extends SceneTree
## Headless authored-content CLI; validation never publishes an Entity or advances dialogue.


#region CLI entry point
func _init() -> void:
	_scan.call_deferred()


func _scan() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Expected output JSON path")
		quit(2)
		return
	var doctor_path: String = "res://content/editor/content_doctor/content_doctor.gd"
	var doctor_script: GDScript = load(doctor_path) as GDScript
	var doctor: RefCounted = doctor_script.new() as RefCounted
	var report: Dictionary = doctor.call("scan") as Dictionary
	var output: FileAccess = FileAccess.open(arguments[0], FileAccess.WRITE)
	if output == null:
		push_error("Cannot write Content Doctor report: %s" % arguments[0])
		quit(2)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(
		"Content Doctor: %d resources, %d scenes, %d dialogues; errors=%d, review=%d"
		% [report.resources, report.scenes, report.dialogues, report.errors, report.review_required]
	)
	print("CONTENT_DOCTOR_COMPLETE")
	quit(0 if bool(report.valid) else 1)
#endregion
