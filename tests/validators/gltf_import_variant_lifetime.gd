extends SceneTree
## Editor-only native regression; run in a scratch project with a byte-identical importer.

const IMPORTER_PATH: String = "res://utils/gltf_import_split_script.gd"
const PROJECT_NAME: String = "PVZ GLTF variant lifetime probe"
const MODES: Array[String] = ["none", "static", "rigid"]
const REPETITIONS: int = 50
const MAX_SCAN_FRAMES: int = 240

var _failures: int = 0
var _checks: int = 0


#region Isolated editor entry and owned test data
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if (
		not Engine.is_editor_hint()
		or ProjectSettings.get_setting("application/config/name") != PROJECT_NAME
	):
		push_error("Run this validator in its isolated headless editor project")
		quit(2)
		return
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	for _frame: int in MAX_SCAN_FRAMES:
		if not filesystem.is_scanning():
			break
		await process_frame
	if filesystem.is_scanning():
		push_error("Isolated editor scan did not settle within the frame budget")
		quit(2)
		return
	var directory: String = "user://variant_%d" % Time.get_ticks_usec()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Cannot create disposable output directory")
		quit(2)
		return
	var original: Node3D = Node3D.new()
	original.name = "Original"
	original.position = Vector3(2.0, 3.0, 4.0)
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = BoxMesh.new()
	visual.position = Vector3.RIGHT
	original.add_child(visual)
	visual.owner = original
	var paths: Dictionary[String, String] = { }
	for mode: String in MODES:
		paths[mode] = directory.path_join("variant_%s.tscn" % mode)
	var importer_script: Script = load(IMPORTER_PATH) as Script
	var importer: RefCounted = importer_script.new() as RefCounted
	for mode: String in MODES:
		importer.call("_save_variant", original, paths[mode], mode, { }, { })
	# Use identical frame drains before both measurement gates.
	await process_frame
	await process_frame
	# Editor output history can allocate Objects; measure an equally sized print-only control.
	var log_before: Dictionary[String, int] = _metrics()
	for line: int in REPETITIONS * MODES.size():
		print("GLTF_EDITOR_OUTPUT_CONTROL ", line)
	await process_frame
	await process_frame
	var log_after: Dictionary[String, int] = _metrics()
	print(
		"GLTF_LOG_METRICS before=",
		JSON.stringify(log_before),
		" after=",
		JSON.stringify(log_after),
	)
	var before: Dictionary[String, int] = _metrics()
	for _iteration: int in REPETITIONS:
		for mode: String in MODES:
			importer.call("_save_variant", original, paths[mode], mode, { }, { })
	await process_frame
	await process_frame
	var after: Dictionary[String, int] = _metrics()
	print("GLTF_VARIANT_METRICS before=", JSON.stringify(before), " after=", JSON.stringify(after))
	_check(after.nodes == before.nodes, "temporary variant Nodes must not accumulate")
	_check(after.orphans == before.orphans, "detached variant roots must be released")
	_check(original.name == &"Original", "source name preserved")
	_check(original.position == Vector3(2.0, 3.0, 4.0), "source transform preserved")
	_check(original.get_child_count() == 1, "source hierarchy preserved")
	_check(visual.position == Vector3.RIGHT and visual.owner == original, "source child preserved")
	for mode: String in MODES:
		_check_saved_variant(paths[mode], mode, original.position)
		DirAccess.remove_absolute(paths[mode])
	original.free()
	DirAccess.remove_absolute(directory)
	await process_frame
	await process_frame
	print("GLTF variant lifetime: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("GLTF_CHECK_FAIL: ", message)


func _metrics() -> Dictionary[String, int]:
	return {
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"static_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
	}
#endregion


#region Saved native scene fidelity after temporary-tree cleanup
func _check_saved_variant(path: String, mode: String, original_position: Vector3) -> void:
	var packed: PackedScene = ResourceLoader.load(
		path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as PackedScene
	_check(packed != null, "saved %s scene remains loadable" % mode)
	if packed == null:
		return
	var restored: Node3D = packed.instantiate() as Node3D
	_check(restored.position == original_position, "saved %s root transform preserved" % mode)
	match mode:
		"none":
			_check(not restored is PhysicsBody3D, "none variant root type")
			_check(restored.get_node("Visual") is MeshInstance3D, "none variant visual")
		"static":
			_check(restored is StaticBody3D, "static variant root type")
			var collision: CollisionShape3D = restored.get_node("Visual_col") as CollisionShape3D
			_check(collision.shape is ConcavePolygonShape3D, "static variant collision type")
		"rigid":
			_check(restored is RigidBody3D, "rigid variant root type")
			var collision: CollisionShape3D = restored.get_node("Visual_col") as CollisionShape3D
			_check(collision.shape is ConvexPolygonShape3D, "rigid variant collision type")
	restored.free()
#endregion
