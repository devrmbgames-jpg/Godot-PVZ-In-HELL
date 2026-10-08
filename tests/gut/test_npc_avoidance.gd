extends GutTest
## Native RVO и реальные RigidBody: обход происходит до физического толкания соседей/очереди.

const NPC_SCENE: PackedScene = preload("res://content/domains/customers/entities/customer.tscn")
const TRADER_SCENE: PackedScene = preload("res://content/entities/commerce/trader.tscn")
const SETTLE_FRAMES: int = 12
const ROUTE_FRAMES: int = 420
const CONTACT_DISTANCE: float = 0.59
const WAITING_POSITION_TOLERANCE: float = 0.05
const CORRIDOR_HALF_WIDTH: float = 1.0
const NAV_CORRIDOR_HALF_WIDTH: float = 0.65

var _world: World = null
var _floor: StaticBody3D = null
var _region: NavigationRegion3D = null
var _barriers: Array[StaticBody3D] = []


#region Native-окружение и освобождение
## Создаёт реальные пол/регион и S_NpcIntent, ожидая синхронизации physics/navmesh.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_NpcIntent.new())
	_floor = StaticBody3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(30.0, 0.5, 30.0)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	_floor.add_child(collision)
	_floor.position.y = -0.25
	add_child(_floor)
	_region = NavigationRegion3D.new()
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-14, 0, -14), Vector3(-14, 0, 14), Vector3(14, 0, 14), Vector3(14, 0, -14)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_region.navigation_mesh = mesh
	add_child(_region)
	set_physics_process(true)
	for frame: int in SETTLE_FRAMES:
		await get_tree().physics_frame


func _physics_process(delta: float) -> void:
	if is_instance_valid(_world):
		_world.process(delta)


## Останавливает шаг World, освобождает его и авторские препятствия теста.
func after_each() -> void:
	set_physics_process(false)
	_world.purge(false)
	_world.free()
	_world = null
	ECS.world = null
	_region.free()
	_floor.free()
	for barrier: StaticBody3D in _barriers:
		barrier.free()
	_barriers.clear()
	await get_tree().process_frame


func _npc(at: Vector3, trader: bool = false) -> E_NpcCharacter:
	var npc: E_NpcCharacter = (TRADER_SCENE if trader else NPC_SCENE).instantiate() as E_NpcCharacter
	npc.position = at
	_world.add_entity(npc)
	return npc


#endregion

#region Проход и участие тела
## Встречные капсулы обходят друг друга в узком коридоре и достигают обеих целей без контакта.
func test_head_on_clients_pass_without_physical_pushing() -> void:
	var narrow: NavigationMesh = NavigationMesh.new()
	narrow.vertices = PackedVector3Array([Vector3(-6, 0, -NAV_CORRIDOR_HALF_WIDTH), Vector3(-6, 0, NAV_CORRIDOR_HALF_WIDTH), Vector3(6, 0, NAV_CORRIDOR_HALF_WIDTH), Vector3(6, 0, -NAV_CORRIDOR_HALF_WIDTH)])
	narrow.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_region.navigation_mesh = narrow
	for side: float in [-CORRIDOR_HALF_WIDTH, CORRIDOR_HALF_WIDTH]:
		var barrier: StaticBody3D = StaticBody3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(12.0, 2.0, 0.1)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		barrier.add_child(collision)
		barrier.position = Vector3(0.0, 1.0, side)
		add_child(barrier)
		_barriers.append(barrier)

	var left: E_NpcCharacter = _npc(Vector3(-4.0, 0.02, 0.0))
	var right: E_NpcCharacter = _npc(Vector3(4.0, 0.02, 0.0))
	NpcIntentService.move_to(left, Vector3(4.0, 0.0, 0.0), 0.25)
	NpcIntentService.move_to(right, Vector3(-4.0, 0.0, 0.0), 0.25)
	var nearest: float = INF
	for frame: int in ROUTE_FRAMES:
		await get_tree().physics_frame
		var separation: Vector3 = left.global_position - right.global_position
		separation.y = 0.0
		nearest = minf(nearest, separation.length())
		if (left.get_component(C_NpcIntent) as C_NpcIntent).arrived and (right.get_component(C_NpcIntent) as C_NpcIntent).arrived:
			break

	assert_gt(nearest, CONTACT_DISTANCE, "Avoid before capsules contact")
	assert_lt(left.global_position.distance_to(Vector3(4.0, 0.0, 0.0)), 0.4, "Left reaches destination: " + str(left.global_position))
	assert_lt(right.global_position.distance_to(Vector3(-4.0, 0.0, 0.0)), 0.4, "Right reaches destination: " + str(right.global_position))


## Клиент обходит торговца, сохраняя исходное положение неподвижного тела в пределах допуска.
func test_client_goes_around_stationary_trader_without_displacing_it() -> void:
	var client: E_NpcCharacter = _npc(Vector3(-4.0, 0.02, 0.0))
	var trader: E_NpcCharacter = _npc(Vector3(0.0, 0.02, 0.0), true)
	for frame: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	var initial: Vector3 = trader.global_position
	NpcIntentService.move_to(client, Vector3(4.0, 0.0, 0.0), 0.25)
	var nearest: float = INF
	for frame: int in ROUTE_FRAMES:
		await get_tree().physics_frame
		nearest = minf(nearest, Vector2(client.global_position.x - trader.global_position.x, client.global_position.z - trader.global_position.z).length())
		if (client.get_component(C_NpcIntent) as C_NpcIntent).arrived:
			break

	assert_gt(nearest, CONTACT_DISTANCE)
	assert_lt(client.global_position.distance_to(Vector3(4.0, 0.0, 0.0)), 0.4, "Client reaches destination: " + str(client.global_position))
	assert_lt(trader.global_position.distance_to(initial), WAITING_POSITION_TOLERANCE)


## Проходящий NPC достигает цели, не сдвигая три физические тела очереди.
func test_client_passes_three_waiting_customers_without_moving_queue() -> void:
	var client: E_NpcCharacter = _npc(Vector3(-4.0, 0.02, 0.0))
	var queue: Array[E_NpcCharacter] = []
	for x: float in [-1.0, 1.0, 3.0]:
		queue.append(_npc(Vector3(x, 0.02, 0.0)))
	for frame: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	var positions: Array[Vector3] = []
	for waiting: E_NpcCharacter in queue:
		positions.append(waiting.global_position)
	NpcIntentService.move_to(client, Vector3(5.0, 0.0, 0.0), 0.25)

	var nearest: float = INF
	for frame: int in ROUTE_FRAMES:
		await get_tree().physics_frame
		for waiting: E_NpcCharacter in queue:
			nearest = minf(nearest, Vector2(client.global_position.x - waiting.global_position.x, client.global_position.z - waiting.global_position.z).length())
		if (client.get_component(C_NpcIntent) as C_NpcIntent).arrived:
			break

	assert_gt(nearest, CONTACT_DISTANCE)
	assert_lt(client.global_position.distance_to(Vector3(5.0, 0.0, 0.0)), 0.4)
	for index: int in queue.size():
		assert_lt(queue[index].global_position.distance_to(positions[index]), WAITING_POSITION_TOLERANCE)


## Смерть отключает движение/avoidance; QA-reset возвращает прежнюю авторскую политику, включая opt-out.
func test_dead_client_stops_navigation_avoidance_and_releases_movement() -> void:
	var client: E_NpcCharacter = _npc(Vector3.ZERO)
	NpcIntentService.move_to(client, Vector3.RIGHT * 4.0, 0.25)
	client.add_component(C_Death.new())
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(client.navigation_agent.avoidance_enabled)
	assert_eq((client.get_component(C_Controller) as C_Controller).direction_motion, Vector3.ZERO)

	var target: DebugTarget = DebugTarget.new()
	target.entity = client
	var reset: DebugServiceResult = DebugHealthService.reset(target)
	assert_true(reset.success)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_true(client.navigation_agent.avoidance_enabled, "Reset restores the native authored policy")
	# Явное авторское отключение avoidance сохраняется через смерть и QA-reset.
	client.navigation_agent.avoidance_enabled = false
	client.add_component(C_Death.new())
	await get_tree().physics_frame
	await get_tree().process_frame
	DebugHealthService.reset(target)
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_false(client.navigation_agent.avoidance_enabled)

#endregion
