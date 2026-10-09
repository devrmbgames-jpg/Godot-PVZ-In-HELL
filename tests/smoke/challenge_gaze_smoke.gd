extends Node
## Исторический сценарий взгляда при приходе: настенный номер, камера/LOS и выдача без диалога.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 3600
const UI_WAIT_FRAMES: int = 32

var _level: Node = null
var _actor: Entity = null
var _customer: E_NpcCharacter = null
var _camera: Camera3D = null


func _ready() -> void:
	_run.call_deferred()


## Проверяет прежнего клиента взгляда, настенный номер и результат физической выдачи.
func _run() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	_actor = _level.get_node("Entityes/Player") as Entity
	(_actor as Node).set_physics_process(false)
	_camera = _actor.get_viewport().get_camera_3d()
	assert(_camera != null and (_actor as Node).is_ancestor_of(_camera))
	_camera.look_at(_camera.global_position + Vector3.DOWN, Vector3.RIGHT)
	for frame: int in WAIT_FRAMES:
		GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break

	var parcel: Entity = PackageQueries.find_live_package("base_supply:1:bottles")
	assert(PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.REGISTERED)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))
	for frame: int in WAIT_FRAMES:
		GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
		await get_tree().physics_frame
		_customer = CustomerFlowQueries.waiting_customer()
		if _customer != null:
			break

	assert(_customer != null)
	(_customer as Node as RigidBody3D).freeze = true
	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
	var identity: StringName = visit.customer_id
	assert(visit.definition.key == &"gaze_customer")
	var state: C_Challenge = _customer.get_component(C_Challenge) as C_Challenge
	assert(state.definition.condition is DEF_GazeChallengeCondition)
	assert(state.phase == C_Challenge.Phase.ACTIVE)
	assert(state.consumed and state.definition.preparation_seconds == 0.0)
	assert(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).is_empty())

	var wall_number: String = "ЗАКАЗ\n№%03d" % CustomerPresentation.registered_number(visit)
	var clues: Array[Node] = get_tree().get_nodes_in_group(GazeOrderCluePresentation.CLUE_GROUP)
	assert(clues.size() == 3)
	var visible_clues: int = 0
	for clue: Node in clues:
		var label: Label3D = clue as Label3D
		var front: Vector3 = label.global_basis.z.normalized()
		var origin: Vector3 = label.global_position + front
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, label.global_position - front, 1)
		var hit: Dictionary = label.get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not hit.is_empty(), "Each authored clue must sit on a physical wall")
		var point: Vector3 = hit.get("position", origin) as Vector3
		assert(origin.distance_to(point) > 1.0, "The wall must not hide the label inside its geometry")
		if GazeOrderCluePresentation.text_for(clue) == wall_number:
			visible_clues += 1
	assert(visible_clues == 1)
	assert(InteractionControlFocus.current(_actor) != InteractionControlFocus.Priority.MODAL)
	_camera.look_at(_customer.head_axis_x.global_position)
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)

	var hud: Node = _level.get_node("InteractionHud/Overlay")
	for frame: int in UI_WAIT_FRAMES:
		await get_tree().process_frame
		if (hud.get_node("GazeDistortion") as ColorRect).visible:
			break

	assert((hud.get_node("GazeWarning") as Label).visible)
	assert((hud.get_node("GazeDistortion") as ColorRect).visible)
	assert((_customer.get_node("DebugStatus") as Label3D).text.contains("LOS:"))
	assert(visit.customer_id == identity and visit.definition.key == &"gaze_customer")
	_camera.look_at(_camera.global_position + Vector3.LEFT)
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
	for frame: int in UI_WAIT_FRAMES:
		await get_tree().process_frame
		if not (hud.get_node("GazeDistortion") as ColorRect).visible:
			break

	assert(state.violation_elapsed == 0.0)
	assert(not (hud.get_node("GazeDistortion") as ColorRect).visible)
	# Авторское правило действует и при входе реальной коробки в физическую зону стойки.
	var counter: E_DeliveryCounter = CustomerFlowQueries.counter()
	var body: RigidBody3D = parcel as Node as RigidBody3D
	body.freeze = true
	body.global_position = (counter as Node as Node3D).global_position + Vector3.UP * 1.3
	for frame: int in 32:
		await get_tree().physics_frame
		GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
		if counter.parcels().has(parcel):
			break

	assert(counter.parcels().has(parcel))
	assert(state.phase == C_Challenge.Phase.ACTIVE)
	assert(CustomerFlowService.confirm_delivery(counter) == PackageDeliveryCheck.Result.READY)
	assert(CustomerFlowService.declare(visit.visit_id, CustomerVisit.Declaration.TAKEN))
	assert(not visit.settlement_committed)
	GameTimeFixture.gameplay(ECS.world, visit.definition.receiving_seconds)
	GameTimeFixture.gameplay(ECS.world, visit.definition.leaving_seconds)
	assert(state.result == ChallengeResult.Type.SUCCESS)
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
	assert(visit.finished and visit.settlement_committed)
	assert(visit.challenge_satisfaction_delta == 10)
	await get_tree().process_frame
	assert(not (hud.get_node("GazeWarning") as Label).visible)
	_level.free()
	ECS.world = null
	print("Challenge gaze arrival wall number camera vignette no-dialogue physical service cleanup smoke PASS")
	get_tree().quit.call_deferred()
