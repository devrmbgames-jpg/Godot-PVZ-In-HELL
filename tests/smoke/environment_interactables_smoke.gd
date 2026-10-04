extends Node
## Проверяет физические шарниры дверей/окон, пределы ящика и блокирование закрытия предметом в Jolt.

const SETTLE_FRAMES: int = 180
const ENDPOINT_TOLERANCE: float = 0.02

var _world: World = null


#region Физический сценарий
func _ready() -> void:
	_run.call_deferred()


## Проверяет авторские пределы joint, физические помехи закрытию и устойчивость к импульсу.
func _run() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var door: E_Openable = _spawn("res://content/entities/doors/door_template.tscn", Vector3.ZERO)
	var window: E_Openable = _spawn("res://content/entities/props/window.tscn", Vector3(4, 1, 0))
	var drawer: E_Openable = _spawn("res://content/entities/props/drawer.tscn", Vector3(7, 1.5, 0))
	for actor: E_Openable in [door, window, drawer]:
		(actor.get_component(C_Openable) as C_Openable).requested_open = true
	await _frames(SETTLE_FRAMES)
	for actor: E_Openable in [door, window, drawer]:
		var state: C_Openable = actor.get_component(C_Openable) as C_Openable
		assert(state.actual_fraction >= 1.0 - ENDPOINT_TOLERANCE, "Openable must reach its authored open endpoint")

	var door_blocker: StaticBody3D = _box(Vector3(0.6, 1.3, -0.6), Vector3(0.4, 0.5, 0.4))
	var drawer_blocker: StaticBody3D = _box(Vector3(7, 1.5, 0), Vector3(0.6, 0.25, 0.2))
	for actor: E_Openable in [door, window, drawer]:
		(actor.get_component(C_Openable) as C_Openable).requested_open = false
	await _frames(SETTLE_FRAMES)
	assert((door.get_component(C_Openable) as C_Openable).actual_fraction > 0.1, "Box must block door closure")
	assert((drawer.get_component(C_Openable) as C_Openable).actual_fraction > 0.1, "Box must block drawer closure")
	assert((window.get_component(C_Openable) as C_Openable).actual_fraction <= ENDPOINT_TOLERANCE)
	door_blocker.queue_free()
	drawer_blocker.queue_free()
	await _frames(SETTLE_FRAMES)
	assert((door.get_component(C_Openable) as C_Openable).actual_fraction <= ENDPOINT_TOLERANCE)
	assert((drawer.get_component(C_Openable) as C_Openable).actual_fraction <= ENDPOINT_TOLERANCE)

	var before: Vector3 = drawer.door_root.global_position
	drawer.door_root.apply_central_impulse(Vector3(100, 100, -100))
	await _frames(SETTLE_FRAMES)
	assert(absf(drawer.door_root.global_position.x - before.x) < ENDPOINT_TOLERANCE)
	assert(absf(drawer.door_root.global_position.y - before.y) < ENDPOINT_TOLERANCE)
	assert(drawer.door_root.position.z >= -0.6 - ENDPOINT_TOLERANCE, "Joint must enforce drawer travel limits")
	_world.free()
	ECS.world = null
	print("Environment door/window/drawer joint obstruction smoke PASS")
	get_tree().quit()


#endregion

#region Тестовые тела и ожидание
func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame


func _spawn(path: String, position: Vector3) -> E_Openable:
	var scene: PackedScene = load(path) as PackedScene
	var actor: E_Openable = scene.instantiate() as E_Openable
	(actor as Node as Node3D).position = position
	_world.add_entity(actor)
	return actor


func _box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	_world.add_child(body)
	return body

#endregion
