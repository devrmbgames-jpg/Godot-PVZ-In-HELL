extends SceneTree
## Offline rebuild of the authored warehouse map from its static physics geometry.

const LEVEL_PATH: String = "res://content/scenes/main_level.tscn"
const OUTPUT_PATH: String = "res://content/navigation/navmesh_warehouse.tres"
const CELL_SIZE: float = 0.15
const CELL_HEIGHT: float = 0.1
## Match the authored NPC capsule/NavigationAgent; exact voxel multiple avoids 0.45m rounding.
const AGENT_RADIUS: float = 0.3
const AGENT_HEIGHT: float = 1.7
const MAX_CLIMB: float = 0.2
const MAX_SLOPE: float = 50.0


func _init() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var scene: PackedScene = load(LEVEL_PATH) as PackedScene
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
	DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	var error: Error = ResourceSaver.save(mesh, OUTPUT_PATH)
	assert(error == OK)
	print("Warehouse navigation bake PASS: polygons=", mesh.get_polygon_count())
	level.free()
	var ecs: Node = root.get_node("ECS")
	ecs.set("world", null)
	quit()
