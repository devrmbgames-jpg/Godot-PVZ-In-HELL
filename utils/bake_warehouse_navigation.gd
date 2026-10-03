extends SceneTree
## Offline rebuild of the authored warehouse map from its static physics geometry.

const LEVEL_PATH: String = "res://content/scenes/main_level.tscn"
const OUTPUT_PATH: String = "res://content/navigation/navmesh_warehouse.tres"
const TEST_LEVEL_PATH: String = "res://content/scenes/primitive_test_level.tscn"
const TEST_OUTPUT_PATH: String = "res://content/navigation/navmesh_primitive_test.tres"
const CELL_SIZE: float = 0.25
const CELL_HEIGHT: float = 0.1
## Authored capsule clearance; Recast rounds it upward on the production 0.25m grid.
const AGENT_RADIUS: float = 0.3
const AGENT_HEIGHT: float = 1.7
const MAX_CLIMB: float = 0.2
const MAX_SLOPE: float = 50.0


func _init() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var primitive: bool = OS.get_cmdline_user_args().has("--primitive")
	var level_path: String = TEST_LEVEL_PATH if primitive else LEVEL_PATH
	var output_path: String = TEST_OUTPUT_PATH if primitive else OUTPUT_PATH
	var previous_uid: int = ResourceLoader.get_resource_uid(output_path)
	var scene: PackedScene = load(level_path) as PackedScene
	var level: Node = scene.instantiate()
	level.set("autosave_path", "")
	root.add_child(level)
	level.set_physics_process(false)
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.cell_size = CELL_SIZE
	mesh.cell_height = CELL_HEIGHT
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = AGENT_HEIGHT
	mesh.agent_max_climb = MAX_CLIMB
	mesh.agent_max_slope = MAX_SLOPE
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, level.get_node("PVZ"))
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	assert(mesh.get_polygon_count() > 0)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var error: Error = ResourceSaver.save(mesh, output_path)
	assert(error == OK)
	if previous_uid != ResourceUID.INVALID_ID:
		assert(ResourceSaver.set_uid(output_path, previous_uid) == OK)
	print("Navigation bake PASS: ", level_path, " polygons=", mesh.get_polygon_count())
	level.free()
	var ecs: Node = root.get_node("ECS")
	ecs.set("world", null)
	quit()
