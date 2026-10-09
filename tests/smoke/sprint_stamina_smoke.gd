extends Node
## Проверяет спринт в основной сцене через реальный ввод; headless подменяет только захват курсора ОС.

## В headless-тесте подменяет только проверку захвата курсора операционной системой.
class CapturedInput extends S_PlayerInput:
	func _accepts_input() -> bool:
		return true

## Отдельный файл настроек сценария; не использует основной профиль игрока.
const TEST_PATH: String = "user://r33_smoke_settings.cfg"
var _level: Node3D


#region Тестовый ввод и ожидание
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame


func _key(code: Key, pressed: bool = true) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame


#endregion

#region Native спринт и настройки
## Прогоняет native движение и ввод Shift, режим переключения, паузу настроек и консольный запрос.
func _run() -> void:
	GameSettingsService.initialize(TEST_PATH)
	GameSettingsService.reset_defaults()
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	_level.set("autosave_path", "")
	add_child(_level)
	var actor: Entity = DebugTargetResolver.player()
	assert(actor != null)

	var body: CharacterBody3D = actor as Node as CharacterBody3D
	var stamina: C_Stamina = actor.get_component(C_Stamina) as C_Stamina
	assert(body != null and stamina != null)
	var menu: SettingsMenu = null
	for node: Node in _level.find_children("*", "CanvasLayer", true, false):
		if node is SettingsMenu:
			menu = node as SettingsMenu
	assert(menu != null)
	menu.setup(actor, TEST_PATH)

	var producer: S_PlayerInput = _level.get_node("World/Systems/Input/S_PlayerInput") as S_PlayerInput
	assert(producer != null)
	producer.set_script(CapturedInput)
	producer.group = "Input"
	# Изолированная ровная площадка для native locomotion, вне игровых объектов.
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(60, 1, 60)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	floor_body.add_child(collider)
	_level.add_child(floor_body)
	floor_body.global_position = Vector3(80, 9.5, 80)
	body.global_position = Vector3(80, 10.05, 80)
	body.velocity = Vector3.ZERO
	await _frames(20)
	await _key(KEY_W)
	await _frames(25)

	var walk_speed: float = Vector2(body.velocity.x, body.velocity.z).length()
	var controller: C_Controller = actor.get_component(C_Controller) as C_Controller
	var motion: C_Motion = actor.get_component(C_Motion) as C_Motion
	print("walk speed=", walk_speed, " position=", body.global_position, " floor=", motion.is_on_floor, " axis=", controller.move_axis, " direction=", controller.direction_motion, " active=", producer.active, " group=", producer.group, " W=", Input.is_action_pressed(&"forward"))
	assert(is_equal_approx(walk_speed, motion.max_speed), "Normal walking reaches authored speed")
	await _key(KEY_SHIFT)
	await _frames(40)
	var run_speed: float = Vector2(body.velocity.x, body.velocity.z).length()
	assert(run_speed > walk_speed * 1.4, "Real native callback consumes sprint multiplier")
	assert(stamina.current < 100.0 and stamina.running, "Input/system/body ordering drains reserve")
	await _key(KEY_SHIFT, false)
	await _frames(5)
	assert(not stamina.running)
	GameSettingsService.set_value("sprint_toggle", true)
	await _key(KEY_SHIFT)
	await _key(KEY_SHIFT, false)
	await _frames(10)
	assert(stamina.running and stamina.toggled, "Toggle survives release")
	await _key(KEY_ESCAPE)
	assert(get_tree().paused)
	assert(not stamina.toggled and not stamina.running, "Settings pause resets sprint")
	await _key(KEY_ESCAPE, false)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE, false)
	assert(not get_tree().paused)
	await _frames(5)
	assert(not stamina.toggled)
	await _key(KEY_W, false)
	assert(Console.console_commands.has("stamina_info"))

	var result: DebugServiceResult = DebugGameplayService.info("stamina", "self")
	assert(result.success)
	Console._on_text_entered("stamina_info")
	assert(Console.rich_label.get_parsed_text().contains("reserve="), "Bare console parser defaults to self")
	Console._on_text_entered("help stamina_info")
	assert(Console.rich_label.get_parsed_text().contains("Read sprint reserve"))
	GameSettingsService.reset_defaults()
	DirAccess.remove_absolute(TEST_PATH)
	_level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("sprint stamina smoke PASS")
	get_tree().quit()

#endregion
