extends SceneTree
## Rebakes the scene's authored NavigationMesh without replacing its generation settings.

const LEVEL_PATH: String = "res://content/scenes/main_level.tscn"
const TEST_LEVEL_PATH: String = "res://content/scenes/primitive_test_level.tscn"
const COVERAGE_CHECKS_PATH: String = "res://utils/warehouse_navigation_checks.gd"

#region Bake workflow
func _init() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var primitive: bool = arguments.has("--primitive")
	var validate_only: bool = arguments.has("--validate-only")
	var check_bake: bool = arguments.has("--check-bake")
	var level_path: String = TEST_LEVEL_PATH if primitive else LEVEL_PATH
	var scene: PackedScene = load(level_path) as PackedScene
	var level: Node3D = scene.instantiate() as Node3D
	level.set("autosave_path", "")
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)

	var region: NavigationRegion3D = level.get_node("WarehouseNavigation") as NavigationRegion3D
	var authored: NavigationMesh = region.navigation_mesh
	if authored == null:
		_finish(level, ["WarehouseNavigation has no authored NavigationMesh"])
		return

	var output_path: String = authored.resource_path
	var previous_uid: int = ResourceLoader.get_resource_uid(output_path)
	var settings: Dictionary[StringName, Variant] = _settings(authored)
	var mesh: NavigationMesh = authored.duplicate() as NavigationMesh
	var errors: Array[String] = []
	if not validate_only:
		mesh.clear()
		var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
		# One parse collects the authored group in the navigation region's coordinate frame.
		# The primitive fixture predates group sources and keeps its explicit PVZ root.
		var parse_root: Node = level.get_node("PVZ") if primitive and mesh.geometry_source_geometry_mode == NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN else region
		NavigationServer3D.parse_source_geometry_data(mesh, source, parse_root)
		if not source.has_data():
			_finish(level, ["Authored navigation source contains no geometry"])
			return
		NavigationServer3D.bake_from_source_geometry_data(mesh, source)

	if _settings(mesh) != settings:
		errors.append("Navigation generation changed authored bake settings")
	region.navigation_mesh = mesh
	# CLI SceneTree scripts compile before project autoload names are registered.
	var coverage_checks: GDScript = load(COVERAGE_CHECKS_PATH) as GDScript
	errors.append_array(await coverage_checks.failures(level, region))
	if not errors.is_empty():
		_finish(level, errors)
		return

	if not validate_only and not check_bake:
		var save_error: Error = ResourceSaver.save(mesh, output_path)
		if save_error != OK:
			_finish(level, ["Cannot save navigation mesh: " + error_string(save_error)])
			return
		if previous_uid != ResourceUID.INVALID_ID:
			var uid_error: Error = ResourceSaver.set_uid(output_path, previous_uid)
			if uid_error != OK:
				_finish(level, ["Cannot preserve navigation resource UID: " + error_string(uid_error)])
				return

	var operation: String = "validation" if validate_only else "dry bake" if check_bake else "bake"
	print("Navigation %s PASS: %s polygons=%d settings preserved" % [operation, level_path, mesh.get_polygon_count()])
	_finish(level, [])
#endregion

#region Settings and cleanup
func _settings(mesh: NavigationMesh) -> Dictionary[StringName, Variant]:
	var settings: Dictionary[StringName, Variant] = {}
	for property: Dictionary in mesh.get_property_list():
		var property_name: StringName = StringName(property["name"])
		var usage: int = int(property["usage"])
		if usage & PROPERTY_USAGE_STORAGE and property_name != &"vertices" and property_name != &"polygons":
			settings[property_name] = mesh.get(property_name)
	return settings


func _finish(level: Node3D, errors: Array[String]) -> void:
	for message: String in errors:
		push_error("Navigation: " + message)
	level.free()
	root.get_node("ECS").set("world", null)
	quit(0 if errors.is_empty() else 1)
#endregion
