extends GutTest
## Регрессии намерений NPC и авторитетных живых целей; подготовка Controller не перемещает тело.

var _world: World = null
var _npc: Entity = null
var _intent: C_NpcIntent = null
var _controller: C_Controller = null


#region Минимальное окружение
## Создаёт минимальный World с производителем намерений и нефизической Entity для проверки границ управления.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_world.add_system(S_NpcIntent.new())
	_npc = _actor([C_NpcIntent.new(), C_Controller.new()])
	_intent = _npc.get_component(C_NpcIntent) as C_NpcIntent
	_controller = _npc.get_component(C_Controller) as C_Controller


## Освобождает World и временные ссылки Controller/Intent; сбрасывает ECS.world.
func after_each() -> void:
	_world.free()
	ECS.world = null
	_world = null
	_npc = null
	_intent = null
	_controller = null


func _actor(components: Array[Component]) -> Entity:
	var body: Node3D = Node3D.new()
	body.set_script(load("res://addons/gecs/ecs/entity.gd"))
	var actor: Entity = body as Node as Entity
	actor.component_resources = components
	_world.add_entity(actor)
	return actor


#endregion

#region Намерения и живые цели
## Высота мировой цели не добавляет вертикального движения; обновляется лишь Controller, позиция остаётся прежней.
func test_world_target_sets_planar_intent_without_moving_body() -> void:
	NpcIntentService.move_to(_npc, Vector3(4, 10, 0), 0.25)
	_world.process(1.0 / 60.0)
	assert_eq(_controller.direction_motion, Vector3.RIGHT)
	assert_eq(_controller.direction_look, Vector3.RIGHT)
	assert_eq((_npc as Node as Node3D).position, Vector3.ZERO)
	assert_false(_intent.arrived)


## Прибытие останавливает запрос движения; уход живой цели возобновляет следование.
func test_arrival_stops_and_resumes_following_when_target_moves() -> void:
	var target: Entity = _actor([])
	NpcIntentService.follow(_npc, target, 0.5)
	_world.process(1.0 / 60.0)
	assert_true(_intent.arrived)
	assert_eq(_controller.direction_motion, Vector3.ZERO)
	(target as Node as Node3D).position = Vector3(0, 0, -2)
	_world.process(1.0 / 60.0)
	assert_false(_intent.arrived)
	assert_eq(_controller.direction_motion, Vector3.FORWARD)


## Независимая цель взгляда обновляется при движении, не заменяя направление ходьбы.
func test_move_and_look_targets_are_independent_live_relationships() -> void:
	var watched: Entity = _actor([])
	(watched as Node as Node3D).position = Vector3(0, 0, -4)
	NpcIntentService.move_to(_npc, Vector3.RIGHT * 4, 0.25)
	NpcIntentService.watch(_npc, watched)
	_world.process(1.0 / 60.0)
	assert_eq(_controller.direction_motion, Vector3.RIGHT)
	assert_eq(_controller.direction_look, Vector3.FORWARD)
	(watched as Node as Node3D).position = Vector3.LEFT * 4
	_world.process(1.0 / 60.0)
	assert_eq(_controller.direction_look, Vector3.LEFT)
	assert_eq(_controller.direction_motion, Vector3.RIGHT)


## Удаление цели освобождает Relationships и переводит взгляд в режим движения без устаревшего намерения.
func test_removed_targets_clear_intent_and_bindings_safely() -> void:
	var target: Entity = _actor([])
	NpcIntentService.follow(_npc, target, 0.25)
	NpcIntentService.watch(_npc, target)
	_world.remove_entity(target)
	_world.process(1.0 / 60.0)
	assert_false(_intent.movement_active)
	assert_false(_intent.arrived)
	assert_eq(_controller.direction_motion, Vector3.ZERO)
	assert_eq(_intent.look_mode, C_NpcIntent.LookMode.MOVEMENT)
	assert_true(_npc.relationships.is_empty())


## Маркер игрока исключает Controller из NPC-производителя и сохраняет его прежнее направление.
func test_player_marker_excludes_actor_from_npc_producer() -> void:
	_npc.add_component(C_PlayerInputController.new())
	NpcIntentService.move_to(_npc, Vector3.RIGHT * 4, 0.25)
	_controller.direction_motion = Vector3.LEFT
	_world.process(1.0 / 60.0)
	assert_eq(_controller.direction_motion, Vector3.LEFT)


## Остановка и смерть гасят движение; терминальное состояние дополнительно освобождает взгляд/живые цели.
func test_stop_and_death_release_targets_and_prevent_motion() -> void:
	var target: Entity = _actor([])
	(target as Node as Node3D).position = Vector3.RIGHT * 4
	NpcIntentService.follow(_npc, target, 0.25)
	NpcIntentService.watch(_npc, target)
	_world.process(1.0 / 60.0)
	NpcIntentService.stop(_npc)
	_world.process(1.0 / 60.0)
	assert_eq(_controller.direction_motion, Vector3.ZERO)
	NpcIntentService.follow(_npc, target, 0.25)
	_npc.add_component(C_Death.new())
	_world.process(1.0 / 60.0)
	assert_eq(_controller.direction_motion, Vector3.ZERO)
	assert_eq(_controller.direction_look, Vector3.ZERO)
	assert_true(_npc.relationships.is_empty())

#endregion
