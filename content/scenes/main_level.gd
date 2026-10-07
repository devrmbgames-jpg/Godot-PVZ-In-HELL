extends Node3D
## Жизненный цикл уровня: восстановление сессии, порядок групп ECS и освобождение World.

## Авторский World, владеющий симуляцией данного уровня.
@export var world: World = null
## Авторский маркер утренней выдачи крупной мебели; перемещение/поворот меняет площадку.
@export var furniture_delivery_anchor: Marker3D = null
## Путь слота автосохранения; пустой отключает автоматическую загрузку, тесты могут задавать отдельный слот.
@export var autosave_path: String = AutosaveStore.DEFAULT_PATH


#region Жизненный цикл уровня
func _ready() -> void:
	ECS.world = world
	assert(world.query.with_all([C_DayCycle]).execute().size() == 1, "Expected one day session")
	var day_session: Entity = world.query.with_all([C_DayCycle]).execute_one()
	day_session.add_component(C_BoundaryTrace.new())
	world.add_observer(O_CustomerPlanning.new())
	world.add_observer(O_CustomerOutcomes.new())
	world.add_observer(O_CustomerGreeting.new())
	world.add_observer(O_CustomerServiceClock.new())
	for owner_type: Script in [S_CustomerVisitPresence, S_CustomerCleanup, S_CustomerClock, S_CustomerGreeting, S_CustomerApproach, S_CustomerWaiting, S_CustomerInspection, S_CustomerDeparture, S_CustomerArrivals]:
		var customer_owner: System = owner_type.new() as System
		customer_owner.group = "GamePlay"
		world.add_system(customer_owner)
	world.add_system(S_LootDrops.new(), true)
	_bind_furniture_delivery()
	DistrictPopulationService.initialize()
	var session: Entity = world.query.with_all([C_Autosave]).execute_one()
	if session != null:
		var save: C_Autosave = session.get_component(C_Autosave) as C_Autosave
		save.path = autosave_path
		if not autosave_path.is_empty():
			GameSessionService.restore_startup(self, save)
	DistrictPopulationService.restore_participation()
	if OS.has_feature("qa_build"):
		print("QA level: ", scene_file_path, "; save slot=", autosave_path)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _bind_furniture_delivery() -> void:
	for zone: Entity in world.query.with_all([C_OrderReceiving]).execute():
		var state: C_OrderReceiving = zone.get_component(C_OrderReceiving) as C_OrderReceiving
		state.furniture_anchor_path = zone.get_path_to(furniture_delivery_anchor) if furniture_delivery_anchor != null else NodePath("")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(world):
		# Рёбра переходов архетипов GECS удерживают друг друга и ресурсы
		# компонентов; purge разрывает циклы перед освобождением сцены.
		# При закрытии дерева дочерние Entity могут освободиться раньше уведомления родителя.
		while not world.entities.is_empty():
			world.entities = world.entities.filter(func(entity: Variant) -> bool: return is_instance_valid(entity))
			if world.entities.is_empty():
				break

			var entity: Entity = world.entities.back() as Entity
			world.remove_entity(entity)
		world.purge(false)
		if ECS.world == world:
			ECS.world = null


#endregion

#region Игровые callbacks
func _physics_process(delta: float) -> void:
	if world == null:
		return

	world.process(delta, "Input")
	world.process(delta, "Interaction")
	world.process(delta, "Physics")
	world.process(delta, "GamePlay")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"menu"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
#endregion
