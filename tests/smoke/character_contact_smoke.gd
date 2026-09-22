extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: World = World.new()
	add_child(world)
	ECS.world = world
	var scene: PackedScene = load("res://content/entities/characters/e_rigid_body_character.tscn")
	var character: RigidBody3D = scene.instantiate() as RigidBody3D
	var standing: CollisionShape3D = character.get_node("ColNormal") as CollisionShape3D
	var bounds: AABB = standing.shape.get_debug_mesh().get_aabb()
	character.position = Vector3(-bounds.end.x - standing.position.x - 0.02, 3.0, 0.0)
	world.add_entity(character as Node as Entity)
	var wall: StaticBody3D = _obstacle(Vector3(0.5, 5, 0), Vector3(1, 20, 20))
	_obstacle(Vector3(10, 5, 0), Vector3(10, 1, 20))
	await get_tree().physics_frame
	await get_tree().physics_frame
	character.linear_velocity = Vector3(2, 5, 2)
	for tick_index: int in 8:
		await get_tree().physics_frame
	assert(character.linear_velocity.y > 3.0, "Wall must not cancel upward jump velocity")
	assert(absf(character.linear_velocity.x) < 0.2, "The wall must actually block normal motion")
	assert(character.linear_velocity.z > 1.8, "Wall must preserve tangential motion")
	wall.queue_free()
	character.position = Vector3(10, 4.5 - standing.position.y - bounds.end.y - 0.01, 0)
	character.linear_velocity = Vector3(2, 5, 2)
	for tick_index: int in 5:
		await get_tree().physics_frame
	assert(character.linear_velocity.y < 1.0, "Ceiling must block upward motion")
	assert(
		character.linear_velocity.x > 1.8 and character.linear_velocity.z > 1.8,
		"Ceiling must preserve horizontal motion",
	)
	var actor: Entity = character as Node as Entity
	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	assert(not motion.is_on_floor, "Ceiling is not a floor")
	world.free()
	ECS.world = null
	print("Character wall/ceiling physics smoke PASS")
	get_tree().quit()


func _obstacle(location: Vector3, dimensions: Vector3) -> StaticBody3D:
	var obstacle: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	obstacle.add_child(collision)
	obstacle.position = location
	add_child(obstacle)
	return obstacle
