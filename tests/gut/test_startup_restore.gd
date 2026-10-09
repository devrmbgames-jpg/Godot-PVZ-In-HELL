extends GutTest
## Actual main-level startup reconstructs defaults/state/links before enabling gameplay reactions.

const SAVE_PATH: String = "user://gut_refactoring_v2_startup.pvzh"
var _level: Node3D = null

#region Actual startup transaction
func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	await get_tree().process_frame
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(SAVE_PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))


## A scene rename does not change actor identity; passive registration cannot replay gameplay effects.
func test_actual_startup_restores_health_before_enabling_effectful_reactions() -> void:
	var packed: PackedScene = _main_scene()
	_level = packed.instantiate() as Node3D
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	var box: Entity = _level.get_node("Entityes/AnchorableTestBox") as Entity
	var player: Entity = _level.get_node("Entityes/Player") as Entity
	var health: C_Health = player.get_component(C_Health) as C_Health
	health.current = health.value * 0.5
	var expected_health: float = health.current
	var snapshot: Dictionary = WorldSnapshotService.capture(_level, 1)
	assert_true(WorldSnapshotService.can_restore(snapshot, _level))
	assert_eq(AutosaveStore.write(snapshot, SAVE_PATH), OK)
	_level.free()

	_level = packed.instantiate() as Node3D
	_level.set("autosave_path", SAVE_PATH)
	box = _level.get_node("Entityes/AnchorableTestBox") as Entity
	box.name = "MovedBox"
	var spy: O_StartupEffectSpy = O_StartupEffectSpy.new()
	_level.get_node("World/Systems/GamePlay").add_child(spy)
	spy.owner = _level
	add_child(_level)
	_level.set_physics_process(false)
	player = _level.get_node("Entityes/Player") as Entity
	assert_eq((player.get_component(C_Health) as C_Health).current, expected_health)
	assert_eq(spy.effects, 0, "No gameplay reaction was dispatched during defaults/overlay/fixup")
	assert_true(ECS.world.observers.has(spy), "Spy was registered by the real World")
	assert_true(spy.active, "The ready world enables future reactions")
	var new_actor: Entity = Entity.new()
	new_actor.component_resources = [C_Health.new()]
	ECS.world.add_entity(new_actor)
	assert_eq(spy.effects, 1, "Fresh gameplay mutations react after readiness")
#endregion


#region Fresh startup reaction scope
## Fresh startup has the same no-partial-composition contract as saved reconstruction.
func test_actual_fresh_startup_suppresses_observers_until_global_ready() -> void:
	var packed: PackedScene = _main_scene()
	_level = packed.instantiate() as Node3D
	_level.set("autosave_path", "")
	var spy: O_StartupEffectSpy = O_StartupEffectSpy.new()
	_level.get_node("World/Systems/GamePlay").add_child(spy)
	spy.owner = _level
	add_child(_level)
	_level.set_physics_process(false)
	var ready_world: GameWorld = ECS.world as GameWorld
	assert_true(ready_world.composition_ready())
	assert_eq(spy.effects, 0,
		"Initial placement and domain startup cannot publish gameplay effects")
	assert_true(spy.active)
	var new_actor: Entity = Entity.new()
	new_actor.component_resources = [C_Health.new()]
	ECS.world.add_entity(new_actor)
	assert_eq(spy.effects, 1, "Future mutations retain normal Observer dispatch")
#endregion


#region Shared authored level selector
func _main_scene() -> PackedScene:
	return load("res://content/scenes/main_level.tscn") as PackedScene
#endregion
