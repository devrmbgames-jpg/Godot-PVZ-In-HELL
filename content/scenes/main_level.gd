extends Node3D

@export var world: World = null
## Tests/embedded scenes may isolate their slot; empty disables automatic loading.
@export var autosave_path: String = AutosaveStore.DEFAULT_PATH


func _ready() -> void:
	ECS.world = world
	assert(world.query.with_all([C_DayCycle]).execute().size() == 1, "Expected one day session")
	var session: Entity = world.query.with_all([C_Autosave]).execute_one()
	if session != null:
		var save: C_Autosave = session.get_component(C_Autosave) as C_Autosave
		save.path = autosave_path
		if not autosave_path.is_empty():
			GameSessionService.restore_startup(self, save)
	if OS.has_feature("qa_build"):
		print("QA level: ", scene_file_path, "; save slot=", autosave_path)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(world):
		# GECS archetypes have transition edges that retain each other and their
		# component resources. Purge breaks those cycles before the scene is freed.
		# Tree shutdown can free Entity children before this parent notification.
		while not world.entities.is_empty():
			world.entities = world.entities.filter(func(entity: Variant) -> bool: return is_instance_valid(entity))
			if world.entities.is_empty():
				break
			var entity: Entity = world.entities.back() as Entity
			world.remove_entity(entity)
		world.purge(false)
		if ECS.world == world:
			ECS.world = null


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
