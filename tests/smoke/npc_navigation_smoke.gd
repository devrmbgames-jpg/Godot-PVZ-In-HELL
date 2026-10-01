extends Node
## A real NavigationAgent path must route a rigid NPC around a wall.

const FRAME_DELTA: float = 1.0 / 60.0
const MAX_FRAMES: int = 600
const START: Vector3 = Vector3(3, 0, 0)
const TARGET: Vector3 = Vector3.ZERO
const ARRIVAL_DISTANCE: float = 0.25
const MIN_ROUTE_DETOUR: float = 1.7

var _world: World = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_NpcIntent.new())
	_box(Vector3(0, -0.5, 0), Vector3(12, 1, 12))
	_box(Vector3(1, 1, 0), Vector3(0.5, 2, 3))
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = 0.3
	mesh.agent_height = 1.7
	mesh.cell_size = 0.15
	mesh.cell_height = 0.1
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, _world)
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	var region: NavigationRegion3D = NavigationRegion3D.new()
	region.navigation_mesh = mesh
	_world.add_child(region)
	var scene: PackedScene = load("res://content/entities/customers/customer.tscn") as PackedScene
	var customer: E_Customer = scene.instantiate() as E_Customer
	(customer as Node as Node3D).position = START
	_world.add_entity(customer)
	assert(customer.navigation_agent != null)
	var body: RigidBody3D = customer as Node as RigidBody3D
	(customer.get_component(C_Motion) as C_Motion).max_speed = 1.8
	NpcIntentService.move_to(customer, TARGET, ARRIVAL_DISTANCE)
	var greatest_detour: float = 0.0
	var arrived: bool = false
	for frame: int in MAX_FRAMES:
		_world.process(FRAME_DELTA)
		await get_tree().physics_frame
		greatest_detour = maxf(greatest_detour, absf(body.position.z))
		if (customer.get_component(C_NpcIntent) as C_NpcIntent).arrived:
			arrived = true
			break
	assert(arrived, "NPC must reach target using NavigationAgent waypoints")
	assert(greatest_detour >= MIN_ROUTE_DETOUR, "Path must go around the wall instead of driving directly into it")
	assert(customer.navigation_agent.get_current_navigation_path().size() > 2)
	_world.free()
	ECS.world = null
	print("NPC NavigationAgent wall-detour pathfinding smoke PASS")
	get_tree().quit()


func _box(position: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	_world.add_child(body)
