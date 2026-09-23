extends Node3D
## Real-body transport regressions: reverse, terrain, collision and explicit handle release.

var _actor: Entity = null
var _cart: Entity = null
var _controller: C_Controller = null


func _ready() -> void:
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_actor) or _controller == null:
		return
	_controller.input_tick += 1
	_controller.direction_look = -(_cart as Node as Node3D).global_basis.z
	S_Grab.handle_input(_actor)


func _run() -> void:
	var world: World = World.new()
	add_child(world)
	ECS.world = world
	world.add_observer(O_GrabLifecycle.new())
	_obstacle(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	var scene: PackedScene = load("res://content/entities/props/push_cart.tscn") as PackedScene
	var cart_body: CharacterBody3D = scene.instantiate() as CharacterBody3D
	cart_body.position = Vector3(0, 0.8, 0)
	_cart = cart_body as Node as Entity
	world.add_entity(_cart)
	var actor_scene: PackedScene = load(
		"res://content/entities/characters/e_rigid_body_character.tscn"
	) as PackedScene
	var actor_body: RigidBody3D = actor_scene.instantiate() as RigidBody3D
	actor_body.position = Vector3(0, 0.05, 1.6)
	_actor = actor_body as Node as Entity
	world.add_entity(_actor)
	_controller = _actor.get_component(C_Controller) as C_Controller
	var config: C_CartTransport = _cart.get_component(C_CartTransport) as C_CartTransport
	for tick: int in 40:
		await get_tree().physics_frame
	assert(cart_body.is_on_floor(), "Cart must settle without dynamic bounce")
	var rest_height: float = cart_body.position.y
	var ray: RayCast3D = S_Grab.interaction_raycast(_actor)
	ray.look_at(cart_body.global_position)
	S_CartTransport.begin(_actor, _cart)
	assert(
		S_CartTransport.current(_actor) == _cart,
		"The aimed cart must acquire its own transport capture",
	)
	assert(S_Push.pushed_object(_actor) == null)
	assert(not _cart.has_component(C_Pushable))

	_controller.move_axis = Vector2(0, -1)
	for tick: int in 90:
		await get_tree().physics_frame
	var forward_position: float = cart_body.position.z
	assert(forward_position < -1.8, "Forward drive must move the loaded-platform body")
	_controller.move_axis = Vector2(0, 1)
	for tick: int in 90:
		await get_tree().physics_frame
	assert(cart_body.position.z > forward_position + 1.0, "S must reverse instead of releasing")
	assert(S_CartTransport.current(_actor) == _cart)
	assert(absf(cart_body.position.y - rest_height) < 0.025)

	_controller.move_axis = Vector2.ZERO
	for tick: int in 25:
		await get_tree().physics_frame
	var start_yaw: float = cart_body.rotation.y
	_controller.move_axis = Vector2(1, 0)
	for tick: int in 35:
		await get_tree().physics_frame
	assert(absf(cart_body.rotation.y - start_yaw) > 0.3, "A/D must steer while coupled")
	_controller.move_axis = Vector2.ZERO
	_controller.interact_pressed = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	_controller.interact_pressed = false
	assert(S_CartTransport.current(_actor) == null, "E explicitly releases the handle")
	assert(InteractionControlFocus.current(_actor) == InteractionControlFocus.Priority.HANDS)
	assert(config.capture_token == 0)
	var terrain_passed: bool = await _terrain_checks(cart_body, actor_body, rest_height)
	assert(terrain_passed)

	set_physics_process(false)
	_actor = null
	_cart = null
	world.free()
	ECS.world = null
	print("Cart transport smoke PASS")
	get_tree().quit()


func _terrain_checks(
	cart_body: CharacterBody3D,
	actor_body: RigidBody3D,
	rest_height: float,
) -> bool:
	var ramp: StaticBody3D = _obstacle(Vector3(8, 0.63, -1), Vector3(4, 0.2, 6))
	ramp.rotation.x = 0.22
	await _place(cart_body, actor_body, Vector3(8, 0.8, 4))
	_controller.move_axis = Vector2(0, -1)
	for tick: int in 150:
		await get_tree().physics_frame
	assert(cart_body.position.y > rest_height + 0.4, "Cart must climb a ramp with its driver")
	assert(S_CartTransport.current(_actor) == _cart)
	var uphill: float = cart_body.position.y
	_controller.move_axis = Vector2(0, 1)
	for tick: int in 180:
		await get_tree().physics_frame
	assert(cart_body.position.y < uphill - 0.3, "Reverse must descend the ramp without detaching")
	assert(S_CartTransport.current(_actor) == _cart)

	_obstacle(Vector3(-8, 0.06, 0), Vector3(4, 0.12, 1))
	_obstacle(Vector3(-8, 1.5, -4), Vector3(4, 3, 0.2))
	await _place(cart_body, actor_body, Vector3(-8, 0.8, 3))
	_controller.move_axis = Vector2(0, -1)
	var highest: float = rest_height
	for tick: int in 240:
		await get_tree().physics_frame
		highest = maxf(highest, cart_body.position.y)
	assert(cart_body.position.z < -1.5, "Cart and driver must traverse a small uneven patch")
	assert(cart_body.position.z > -2.8, "A wall must block transport")
	assert(highest < rest_height + 0.23, "Small bumps must not launch the cart")
	var at_wall: float = cart_body.position.z
	_controller.move_axis = Vector2(0, 1)
	for tick: int in 100:
		await get_tree().physics_frame
	assert(
		cart_body.position.z > at_wall + 1.0,
		"Reverse must get the cart out of a blocked corner",
	)
	assert(S_CartTransport.current(_actor) == _cart)
	S_CartTransport.end(_cart)
	_controller.move_axis = Vector2.ZERO
	return true


func _place(cart_body: CharacterBody3D, actor_body: RigidBody3D, location: Vector3) -> void:
	S_CartTransport.end(_cart)
	_controller.move_axis = Vector2.ZERO
	cart_body.position = location
	cart_body.rotation = Vector3.ZERO
	cart_body.velocity = Vector3.ZERO
	actor_body.position = Vector3(location.x, 0.05, location.z + 1.6)
	actor_body.linear_velocity = Vector3.ZERO
	for tick: int in 30:
		await get_tree().physics_frame
	var ray: RayCast3D = S_Grab.interaction_raycast(_actor)
	ray.look_at(cart_body.global_position)
	S_CartTransport.begin(_actor, _cart)
	assert(S_CartTransport.current(_actor) == _cart)


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
