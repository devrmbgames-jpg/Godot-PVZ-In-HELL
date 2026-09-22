extends GutTest

const MAIN_LEVEL: PackedScene = preload("res://content/scenes/main_level.tscn")


func test_main_scene_profiles_and_registered_grab_pipeline() -> void:
	var level: Node3D = MAIN_LEVEL.instantiate() as Node3D
	add_child(level)
	# Stop automatic input sampling; drive the real ECS groups deterministically below.
	level.set_physics_process(false)
	for delivery_tick: int in 12:
		await get_tree().physics_frame
		ECS.world.process(1.0 / 60.0, "GamePlay")
	var world: World = level.get_node("World") as World
	var player: Entity = level.get_node("Entityes/Player") as Entity
	var light_box: Entity = level.get_node("Entityes/Parcel_001_01") as Entity
	var medium_box: Entity = level.get_node("Entityes/Parcel_001_02") as Entity
	var heavy_box: Entity = level.get_node("Entityes/Parcel_001_03") as Entity
	assert_eq(world.entities.size(), 15)
	assert_eq(ECS.world, world)
	assert_true(world.entities.has(heavy_box))
	var light_config: C_Grabbable = light_box.get_component(C_Grabbable) as C_Grabbable
	var medium_config: C_Grabbable = medium_box.get_component(C_Grabbable) as C_Grabbable
	var heavy_config: C_Grabbable = heavy_box.get_component(C_Grabbable) as C_Grabbable
	assert_gt(light_config.throw_velocity, medium_config.throw_velocity)
	assert_gt(medium_config.throw_velocity, heavy_config.throw_velocity)
	assert_gt(light_config.movement_speed_multiplier, medium_config.movement_speed_multiplier)
	assert_gt(medium_config.movement_speed_multiplier, heavy_config.movement_speed_multiplier)
	assert_eq((light_box as Node as RigidBody3D).mass, 5.0)
	assert_eq((medium_box as Node as RigidBody3D).mass, 30.0)
	assert_eq((heavy_box as Node as RigidBody3D).mass, 80.0)
	var interactor: C_Interactor = player.get_component(C_Interactor) as C_Interactor
	var controller: C_Controller = player.get_component(C_Controller) as C_Controller
	var interaction_ray: RayCast3D = S_Grab.interaction_raycast(player)
	(player as Node as RigidBody3D).freeze = true
	var heavy_position: Vector3 = (heavy_box as Node as Node3D).global_position
	(player as Node as Node3D).global_position = heavy_position + Vector3(0, 0.1, 1.8)
	interaction_ray.look_at((heavy_box as Node as Node3D).global_position + Vector3.UP * 0.2)
	for physics_tick: int in 2:
		await get_tree().physics_frame
	controller.interact_pressed = true
	world.process(1.0 / 60.0, "Interaction")
	assert_eq(S_Grab.held_object(player), heavy_box)
	assert_eq(interactor.target, heavy_box)
	controller.interact_pressed = false
	controller.action_second_held = true
	controller.look_delta = Vector2(25.0, 0.0)
	world.process(1.0 / 60.0, "Interaction")
	var control: C_GrabControl = player.get_component(C_GrabControl) as C_GrabControl
	assert_true(control.rotation_active)
	controller.interact_pressed = true
	world.process(1.0 / 60.0, "Interaction")
	assert_null(S_Grab.held_relationship(heavy_box))
	assert_false(control.rotation_active)
	level.free()
	ECS.world = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
