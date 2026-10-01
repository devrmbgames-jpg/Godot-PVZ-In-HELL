extends Node
## Real shared character physics: obstacle, external impulse, recovery and head look.

const FRAME_DELTA: float = 1.0 / 60.0
const SETTLE_FRAMES: int = 30
const BLOCKED_FRAMES: int = 120
const ARRIVAL_FRAMES: int = 300
const TARGET: Vector3 = Vector3(4, 0, 0)
const ARRIVAL_DISTANCE: float = 0.25
const BLOCKED_MAX_X: float = 0.6
const IMPULSE: Vector3 = Vector3(600, 0, 0)
const MIN_IMPULSE_SPEED: float = 7.0

var _world: World = null
var _customer: E_Customer = null
var _body: RigidBody3D = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_NpcIntent.new())
	_obstacle(Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	var blocker: StaticBody3D = _obstacle(Vector3(1.3, 1, 0), Vector3(1, 2, 3))
	var scene: PackedScene = load("res://content/entities/customers/customer.tscn") as PackedScene
	_customer = scene.instantiate() as E_Customer
	_body = _customer as Node as RigidBody3D
	_world.add_entity(_customer)
	# This fixture isolates collision/impulse behavior; routing has its own real-map smoke.
	(_customer.get_component(C_NpcIntent) as C_NpcIntent).navigation_enabled = false
	var motion: C_Motion = _customer.get_component(C_Motion) as C_Motion
	motion.max_speed = 1.8
	assert(not _customer.has_component(C_PlayerInputController))
	assert(_customer.head_axis_x != null and _customer.head_axis_y != null)
	assert(_customer.animation_player.has_animation(_customer.idle_animation))
	assert(_customer.animation_player.has_animation(_customer.walk_animation))
	await _frames(SETTLE_FRAMES)
	assert(motion.is_on_floor, "Customer must use shared grounded contact detection")
	NpcIntentService.move_to(_customer, TARGET, ARRIVAL_DISTANCE)
	await _frames(BLOCKED_FRAMES)
	assert(_body.position.x <= BLOCKED_MAX_X, "Solid box must block NPC without teleport-through")
	assert(not (_customer.get_component(C_NpcIntent) as C_NpcIntent).arrived)
	blocker.queue_free()
	await _arrive()
	NpcIntentService.stop(_customer)
	await _frames(SETTLE_FRAMES)
	var before_impulse: Vector3 = _body.position
	_body.apply_central_impulse(IMPULSE)
	await _frames(2)
	assert(_body.linear_velocity.x > MIN_IMPULSE_SPEED, "Shared solver must preserve external impulse")
	assert(_body.position.x > before_impulse.x, "External impulse must physically displace NPC")
	NpcIntentService.move_to(_customer, TARGET, ARRIVAL_DISTANCE)
	await _arrive()
	NpcIntentService.stop(_customer)
	var watched_body: Node3D = Node3D.new()
	watched_body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var watched: Entity = watched_body as Node as Entity
	_world.add_entity(watched)
	watched_body.global_position = _body.global_position + Vector3(4, 1.6, 0)
	NpcIntentService.watch(_customer, watched)
	await _frames(SETTLE_FRAMES)
	var controller: C_Controller = _customer.get_component(C_Controller) as C_Controller
	assert(controller.direction_look.y > 0.0, "Gaze must originate at the character head")
	assert(absf(_customer.head_axis_x.rotation.x) > 0.01, "Shared look solver must rotate NPC head")
	_world.free()
	ECS.world = null
	print("NPC obstacle/impulse/recovery/head-look physics smoke PASS")
	get_tree().quit()


func _frames(count: int) -> void:
	for frame: int in count:
		_world.process(FRAME_DELTA)
		await get_tree().physics_frame


func _arrive() -> void:
	for frame: int in ARRIVAL_FRAMES:
		await _frames(1)
		var intent: C_NpcIntent = _customer.get_component(C_NpcIntent) as C_NpcIntent
		if intent.arrived:
			return
	assert(false, "NPC must recover and reach the target within frame budget")


func _obstacle(location: Vector3, dimensions: Vector3) -> StaticBody3D:
	var obstacle: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	obstacle.add_child(collision)
	obstacle.position = location
	_world.add_child(obstacle)
	return obstacle
