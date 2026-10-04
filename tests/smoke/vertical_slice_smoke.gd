extends Node
## Ordinary input driver. Only the headless mouse-capture OS boundary is substituted.

const SAVE_PATH: String = "user://vertical_slice_smoke.pvzh"
const WAIT_FRAMES: int = 900
const AIM_FRAMES: int = 180
const MOVE_FRAMES: int = 1200
const AIM_TOLERANCE: float = 0.012
const MOVE_TOLERANCE: float = 0.2
const MAIN: PackedScene = preload("res://content/scenes/main_level.tscn")
const SUPPLY_SEED: int = 2302

class CapturedInput extends S_PlayerInput:
	func _accepts_input() -> bool:
		return true

	func deps() -> Dictionary[int, Array]:
		return {Runs.Before: [S_PlayerIntent]}

var _level: Node3D = null
var _player: E_RigidBodyCharacter = null
var _controller: C_Controller = null
var _camera: Camera3D = null
var _failed: bool = false
var _actions: Dictionary[StringName, float] = {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(SUPPLY_SEED)
	get_window().size = Vector2i(1920, 1080)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_level = MAIN.instantiate() as Node3D
	_level.set("autosave_path", SAVE_PATH)
	add_child(_level)
	_player = _level.get_node("Entityes/Player") as E_RigidBodyCharacter
	_controller = _player.get_component(C_Controller) as C_Controller
	_camera = _player.get_node("HeadY/HeadX/HeadRoot/Camera3D") as Camera3D

	var input: System = _level.get_node("World/Systems/Input/S_PlayerInput") as System
	ECS.world.remove_system(input)
	await get_tree().process_frame
	var producer: CapturedInput = CapturedInput.new()
	producer.group = "Input"
	producer.name = "S_PlayerInput"
	ECS.world.add_system(producer, true)
	for frame: int in WAIT_FRAMES:
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break
	if not _check(ECS.world.query.with_all([C_Package]).execute().size() == 8, "eight packages arrive"):
		_finish()
		return

	print("R23 route: native player start ", _player.global_position)
	var scanner: Entity = _level.get_node("Entityes/Scanner") as Entity
	if not await _aim(_point(scanner)):
		_finish()
		return

	await _tap(&"interact")
	if not _check(GrabService.held_relationship(scanner) != null, "scanner picked up using E"):
		_finish()
		return
	if not await _walk(Vector3(8.0, 0.0, 1.0)):
		_finish()
		return

	for key: String in ["books", "glass", "clothes", "bottles", "tools", "equipment", "oil", "power_cells"]:
		var parcel: Entity = CustomerFlowService.parcel_for("base_supply:1:" + key)
		print("R23 route: scan ", key, " at ", _point(parcel))
		var position: Vector3 = _point(parcel)
		var near: Vector3 = position + Vector3(0.0, 0.0, -1.3)
		if not await _walk(Vector3(position.x, 0.0, 1.0)) or not await _walk(near) or not await _aim(_point(parcel), parcel):
			_finish()
			return

		await _tap(&"action_primary")
		var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
		if not _check(state.registration_number > 0, "scan " + key + " by held scanner"):
			_finish()
			return
	if not await _morning_terminal() or not await _ordinary_customer():
		_finish()
		return

	print("PASS: vertical slice M2 draft: ordinary inputs, eight scans, Terminal and normal customer delivery/declaration")
	_finish()


func _morning_terminal() -> bool:
	var terminal: Entity = _level.get_node("Entityes/Terminal") as Entity
	if not await _walk(Vector3(2.0, 0.0, -2.8)) or not await _aim(_point(terminal), terminal):
		return false

	print("R23 Terminal aim ", (_player.get_component(C_Interactor) as C_Interactor).target, " · ", (_player.get_component(C_Interactor) as C_Interactor).prompt_text)
	await _tap(&"interact")
	var panel: TerminalPanel = terminal.get_node("TerminalPanel") as TerminalPanel
	if not _check(panel.visible, "open Terminal using E"):
		return false

	var rows: Array[Node] = panel.find_children("*", "UI_TerminalButtonPackage", true, false)
	if not _check(rows.size() == 8, "Terminal lists all eight scanned packages"):
		return false

	for row: Node in rows:
		if (row as UI_TerminalButtonPackage).package_id() == "base_supply:1:equipment":
			await _press_button(row.get_node("%Button") as Button)
			break

	await _tap(&"menu")
	return _check(not panel.visible, "close Terminal using Escape")


func _ordinary_customer() -> bool:
	var station: Entity = _level.get_node("Entityes/ShiftConsole") as Entity
	if not await _walk(Vector3(2.0, 0.0, -5.7)) or not await _aim(_point(station), station):
		return false

	await _tap(&"interact")
	if not _check(DayPhaseService.current().phase == C_DayCycle.Phase.DAY, "start shift using E"):
		return false

	var visit: CustomerVisit = CustomerFlowService.find_visit(&"visit/base_supply:1:books")
	var customer: E_Customer = null
	for frame: int in WAIT_FRAMES * 3:
		await get_tree().physics_frame
		customer = CustomerFlowService.customer_for(visit.visit_id)
		if customer != null:
			var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
			if agent.phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE:
				break
		if visit.finished:
			break
	if not _check(customer != null and not visit.finished and (customer.get_component(C_CustomerAgent) as C_CustomerAgent).phase == C_CustomerAgent.Phase.WAITING_FOR_PACKAGE, "ordinary NPC physically reaches waiting position"):
		return false

	print("R23 ordinary customer position ", customer.global_position)
	if not await _walk(customer.global_position + Vector3(0.0, 0.0, -1.3)) or not await _aim(_point(customer), customer):
		return false

	await _tap(&"interact")
	if not await _complete_dialogue("Хорошо"):
		return false

	var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
	var point: Vector3 = _point(parcel)
	if not await _walk(Vector3(7.0, 0.0, 4.6)) or not await _walk(Vector3(point.x, 0.0, 4.6)) or not await _walk(point + Vector3(0.0, 0.0, 1.3)) or not await _aim(_point(parcel), parcel):
		return false

	print("R23 pickup books target ", (_player.get_component(C_Interactor) as C_Interactor).target)
	await _tap(&"interact")
	if not _check(GrabService.held_object(_player) == parcel, "books picked up using E"):
		return false
	if not await _walk(customer.global_position + Vector3(0.0, 0.0, -1.3)) or not await _aim(_point(customer), customer):
		return false

	print("R23 handoff: held ", GrabService.held_object(_player), " target ", (_player.get_component(C_Interactor) as C_Interactor).target, " · ", (_player.get_component(C_Interactor) as C_Interactor).prompt_text)
	await _tap(&"use")
	print("R23 handoff result: actual ", CustomerVisit.Actual.keys()[visit.actual], " declaration ", CustomerVisit.Declaration.keys()[visit.declaration], " · ", (customer.get_node("Message") as Label3D).text)
	if not _check(visit.actual == CustomerVisit.Actual.DELIVERED and visit.declaration == CustomerVisit.Declaration.NONE, "physical handoff preserves separate declaration"):
		return false

	var terminal: Entity = _level.get_node("Entityes/Terminal") as Entity
	if not await _walk(Vector3(2.0, 0.0, -2.8)) or not await _aim(_point(terminal), terminal):
		return false

	await _tap(&"interact")
	var panel: TerminalPanel = terminal.get_node("TerminalPanel") as TerminalPanel
	for row: Node in panel.find_children("*", "UI_TerminalButtonPackage", true, false):
		if (row as UI_TerminalButtonPackage).package_id() == visit.package_id:
			await _press_button(row.get_node("%ButtonOK") as Button)
			break

	await _tap(&"menu")
	return _check(visit.declaration == CustomerVisit.Declaration.TAKEN, "Terminal TAKEN through normal UI input")


func _complete_dialogue(response_text: String) -> bool:
	if not _check(not get_tree().get_nodes_in_group(CustomerDialoguePanel.ACTIVE_GROUP).is_empty(), "dialogue opened through interaction"):
		return false

	for frame: int in 120:
		await _step()
		var dialogs: Array[Node] = get_tree().get_nodes_in_group(CustomerDialoguePanel.ACTIVE_GROUP)
		if dialogs.is_empty():
			return true

		var buttons: Array[Node] = dialogs[0].find_children("*", "Button", true, false)
		var response: Button = null
		for node: Node in buttons:
			var button: Button = node as Button
			if button.is_visible_in_tree() and not button.disabled and (button.text.contains(response_text) or button.text == "Продолжить"):
				response = button
				break
		if response != null:
			await _press_button(response)
	return _check(false, "dialogue UI completion")


func _press_button(button: Button) -> void:
	button.grab_focus()
	await _tap(&"ui_accept")


func _step(frames: int = 3) -> void:
	for frame: int in frames:
		await get_tree().physics_frame


func _action(action: StringName, strength: float) -> void:
	if is_equal_approx(_actions.get(action, 0.0), strength):
		return

	_actions[action] = strength
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = strength > 0.0
	event.strength = strength
	Input.parse_input_event(event)


func _tap(action: StringName) -> void:
	_action(action, 1.0)
	await _step()
	_action(action, 0.0)
	await _step()


func _point(entity: Entity) -> Vector3:
	var shapes: Array[Node] = entity.find_children("*", "CollisionShape3D", true, false)
	if not shapes.is_empty():
		return (shapes[0] as CollisionShape3D).global_position
	return (entity as Node as Node3D).global_position


func _look(position: Vector3) -> void:
	var desired: Vector3 = (position - _camera.global_position).normalized()
	var current: Vector3 = _controller.direction_look.normalized()
	var yaw: float = Vector3(current.x, 0.0, current.z).signed_angle_to(Vector3(desired.x, 0.0, desired.z), Vector3.UP)
	var pitch: float = asin(clampf(desired.y, -1.0, 1.0)) - asin(clampf(current.y, -1.0, 1.0))
	var load: C_CarryLoad = _player.get_component(C_CarryLoad) as C_CarryLoad
	var strength: C_Strength = _player.get_component(C_Strength) as C_Strength
	var mobility: float = CarryLoadPolicy.active_multiplier(load, strength)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = -Vector2(yaw, pitch) / (S_PlayerIntent.LOOK_SENSITIVITY * mobility)
	Input.parse_input_event(event)


func _aim(position: Vector3, target: Entity = null) -> bool:
	for frame: int in AIM_FRAMES:
		if target != null:
			position = _point(target)
		if frame % 6 == 0:
			_look(position)
		await get_tree().physics_frame
		var desired: Vector3 = (position - _camera.global_position).normalized()
		if (-_camera.global_basis.z).angle_to(desired) < AIM_TOLERANCE:
			await _step()
			return true
	return _check(false, "aim timeout at %s; look %s camera %s" % [position, _controller.direction_look, -_camera.global_basis.z])


func _walk(position: Vector3) -> bool:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_player.get_world_3d().navigation_map, _player.global_position, position, true)
	print("R23 input route to ", position, " · ", path.size(), " waypoints")
	if not _check(not path.is_empty(), "navigation route toward " + str(position)):
		return false

	for waypoint: Vector3 in path:
		if not await _walk_segment(waypoint):
			return false
	return await _walk_segment(position)


func _walk_segment(position: Vector3) -> bool:
	var progress: Vector3 = _player.global_position
	if GrabService.held_in_slot(_player, C_Grabbable.HoldSlot.CARRY) != null:
		if not await _aim(Vector3(position.x, _camera.global_position.y, position.z)):
			return false

	for frame: int in MOVE_FRAMES:
		var death: C_Death = _player.get_component(C_Death) as C_Death
		if death != null:
			_stop_move()
			return _check(false, "player died during movement; cause %s source %s amount %s" % [DamageRequest.Type.keys()[death.cause.request.damage_type], death.cause.request.source, death.cause.request.amount])

		var offset: Vector3 = position - _player.global_position
		offset.y = 0.0
		if offset.length() <= MOVE_TOLERANCE:
			_stop_move()
			await _step(12)
			return true

		var direction: Vector3 = offset.normalized()
		var forward: Vector3 = _controller.direction_look
		forward.y = 0.0
		forward = forward.normalized()
		var right: Vector3 = forward.cross(Vector3.UP)
		var speed: float = clampf(offset.length() * 2.0, 0.12, 1.0)
		_action(&"forward", maxf(0.0, direction.dot(forward)) * speed)
		_action(&"back", maxf(0.0, -direction.dot(forward)) * speed)
		_action(&"right", maxf(0.0, direction.dot(right)) * speed)
		_action(&"left", maxf(0.0, -direction.dot(right)) * speed)
		if frame % 200 == 199:
			print("R23 movement debug: ", _player.global_position, " velocity ", _player.linear_velocity, " raw ", Input.get_vector(&"left", &"right", &"forward", &"back"), " motion ", _controller.direction_motion, " requested ", direction)
		if frame % 60 == 59:
			if _player.global_position.distance_to(progress) < 0.1:
				await _tap(&"jump")
			progress = _player.global_position
		await get_tree().physics_frame
	_stop_move()
	return _check(false, "walk timeout toward %s; player %s" % [position, _player.global_position])


func _stop_move() -> void:
	for action: StringName in [&"forward", &"back", &"left", &"right"]:
		_action(action, 0.0)


func _check(condition: bool, description: String) -> bool:
	if not condition:
		_failed = true
		push_error("R23 ordinary input: " + description)
	return condition


func _finish() -> void:
	for action: StringName in _actions.keys():
		_action(action, 0.0)
	_level.free()
	await _step(30)
	get_tree().quit(1 if _failed else 0)
