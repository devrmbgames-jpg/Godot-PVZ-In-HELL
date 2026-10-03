extends GutTest
## Real host startup/cleanup and primitive-level placement/navigation contracts.

const LEVEL_PATHS: Array[String] = [
	"res://content/scenes/main_level.tscn",
	"res://content/scenes/primitive_test_level.tscn",
]
const WORLD_SCENE: String = "res://content/scenes/game_world.tscn"
const STARTUP_FRAMES: int = 12


func test_both_hosts_register_once_and_release_world_on_exit() -> void:
	var configurations: Array[String] = []
	for path: String in LEVEL_PATHS:
		var packed: PackedScene = load(path) as PackedScene
		var level: Node3D = packed.instantiate() as Node3D
		level.set("autosave_path", "")
		add_child(level)
		var world: World = level.get_node("World") as World
		assert_eq(world.scene_file_path, WORLD_SCENE)
		assert_same(ECS.world, world)
		for frame: int in STARTUP_FRAMES:
			await get_tree().physics_frame
		assert_eq(world.query.with_all([C_DayCycle]).execute().size(), 1)
		assert_eq(world.query.with_all([C_PlayerInputController]).execute().size(), 1)
		assert_eq(world.query.with_all([C_Trader]).execute().size(), 1)
		var seen: Dictionary[int, bool] = {}
		for entity: Entity in world.entities:
			assert_false(seen.has(entity.get_instance_id()), "No duplicate Entity registration")
			seen[entity.get_instance_id()] = true
		var systems: Node = world.get_node("Systems")
		for coarse: Node in systems.get_children():
			for child: Node in coarse.get_children():
				if child is System:
					var system: System = child as System
					assert_eq(system.group, String(coarse.name))
					var script: Script = system.get_script() as Script
					configurations.append("%s/%s:%s" % [coarse.name, child.name, script.resource_path])
		level.free()
		assert_null(ECS.world, "Host cleanup releases singleton before next level")
		await get_tree().process_frame
	var midpoint: int = int(configurations.size() / 2)
	assert_gt(midpoint, 0, "Runtime systems were registered")
	assert_eq(configurations.slice(0, midpoint), configurations.slice(midpoint), "Both hosts run the same authored systems")


func test_primitive_floor_routes_and_separate_save_slot() -> void:
	var packed: PackedScene = load(LEVEL_PATHS[1]) as PackedScene
	var level: Node3D = packed.instantiate() as Node3D
	assert_eq(level.get("autosave_path"), "user://primitive_test_level.pvzh")
	level.set("autosave_path", "")
	add_child(level)
	for frame: int in STARTUP_FRAMES:
		await get_tree().physics_frame
	var floor_collision: CollisionShape3D = level.get_node("PVZ/Floor/Collision") as CollisionShape3D
	var box: BoxShape3D = floor_collision.shape as BoxShape3D
	assert_eq(box.size, Vector3(80.0, 0.5, 64.0))
	assert_almost_eq(floor_collision.global_position.y + box.size.y / 2.0, 0.0, 0.001)
	for name: String in ["Hammer", "UtilityBlade", "Marker", "Marker2", "Marker3", "FoodPickup", "MedPickup", "WrapPickup"]:
		var prop: Node3D = level.get_node("Entityes/" + name) as Node3D
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(prop.global_position + Vector3.UP, prop.global_position + Vector3.DOWN * 3.0, 1)
		var hit: Dictionary = prop.get_world_3d().direct_space_state.intersect_ray(ray)
		assert_false(hit.is_empty(), "Solid support for " + name)
	var previous: Node3D = null
	for name: String in ["Valve_E_Press", "Valve_F_Decay", "Valve_F_Instant", "Valve_F_OnComplete", "Valve_F_Never"]:
		var valve: Node3D = level.get_node("Entityes/" + name) as Node3D
		if previous != null:
			assert_almost_eq(previous.global_position.distance_to(valve.global_position), 2.0, 0.01)
		previous = valve
	var entry: Node3D = level.get_node("Entityes/DeliveryCounter/Entry") as Node3D
	var waiting: Node3D = level.get_node("Entityes/DeliveryCounter/Waiting") as Node3D
	var map: RID = entry.get_world_3d().navigation_map
	var route: PackedVector3Array = NavigationServer3D.map_get_path(map, entry.global_position, waiting.global_position, true)
	assert_gte(route.size(), 2, "Baked customer arrival/departure route exists")
	assert_lt(route[0].distance_to(entry.global_position), 0.3)
	assert_lt(route[route.size() - 1].distance_to(waiting.global_position), 0.3)
	level.free()
	await get_tree().process_frame
