extends Node
## Default gaze customer: real demand, camera/LOS, warning, physical package service and cleanup.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 900
const UI_WAIT_FRAMES: int = 32

var _level: Node = null
var _actor: Entity = null
var _customer: E_Customer = null
var _camera: Camera3D = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	add_child(_level)
	_level.set_physics_process(false)
	_actor = _level.get_node("Entityes/Player") as Entity
	(_actor as Node as RigidBody3D).freeze = true
	_camera = _actor.get_viewport().get_camera_3d()
	assert(_camera != null and (_actor as Node).is_ancestor_of(_camera))
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break
	var parcel: Entity = CustomerFlowService.parcel_for("base_supply:1:bottles")
	assert(PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.REGISTERED)
	var cycle: C_DayCycle = DayPhaseService.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		_customer = CustomerFlowService.waiting_customer()
		if _customer != null:
			break
	assert(_customer != null)
	(_customer as Node as RigidBody3D).freeze = true
	var agent: C_CustomerAgent = _customer.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	var identity: StringName = visit.customer_id
	assert(visit.definition.key == &"gaze_customer")
	var state: C_Challenge = _customer.get_component(C_Challenge) as C_Challenge
	assert(state.definition.condition is DEF_GazeChallengeCondition)
	assert(CustomerDialogueService.start(_actor, _customer))
	var panel: CustomerDialoguePanel = null
	for frame: int in UI_WAIT_FRAMES:
		await get_tree().process_frame
		var panels: Array[Node] = get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP)
		if not panels.is_empty():
			panel = panels[0] as CustomerDialoguePanel
			if panel.find_children("*", "RichTextLabel", true, false).size() > 0:
				var label: RichTextLabel = panel.find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
				if label.text.contains("3 секунд"):
					break
	assert(panel != null)
	var acknowledged: bool = false
	for node: Node in panel.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == "Продолжить" and button.visible:
			button.pressed.emit()
			acknowledged = true
			break
	assert(acknowledged)
	for frame: int in UI_WAIT_FRAMES:
		await get_tree().process_frame
		if state.phase == C_Challenge.Phase.ACTIVE:
			break
	assert(state.phase == C_Challenge.Phase.ACTIVE)
	assert(InteractionControlFocus.current(_actor) != InteractionControlFocus.Priority.MODAL)
	_camera.look_at(_customer.head_axis_x.global_position)
	ECS.world.process(state.definition.preparation_seconds, "GamePlay")
	ECS.world.process(2.0, "GamePlay")
	await get_tree().process_frame
	var hud: Node = _level.get_node("InteractionHud/Overlay")
	assert((hud.get_node("GazeWarning") as Label).visible)
	assert((hud.get_node("GazeDistortion") as ColorRect).visible)
	assert((hud.get_node("ChallengeDebugPanel/Text") as Label).text.contains("LOS:"))
	assert(visit.customer_id == identity and visit.definition.key == &"gaze_customer")
	_camera.look_at(_camera.global_position + Vector3.LEFT)
	ECS.world.process(FRAME_DELTA, "GamePlay")
	await get_tree().process_frame
	assert(state.violation_elapsed == 0.0)
	assert(not (hud.get_node("GazeDistortion") as ColorRect).visible)
	# The authored rule remains active while a real parcel enters the counter's physical area.
	var counter: E_DeliveryCounter = CustomerFlowService.counter()
	var body: RigidBody3D = parcel as Node as RigidBody3D
	body.freeze = true
	body.global_position = (counter as Node as Node3D).global_position + Vector3.UP * 1.3
	for frame: int in 32:
		await get_tree().physics_frame
		ECS.world.process(FRAME_DELTA, "GamePlay")
		if counter.parcels().has(parcel):
			break
	assert(counter.parcels().has(parcel))
	assert(state.phase == C_Challenge.Phase.ACTIVE)
	assert(CustomerFlowService.confirm_delivery(counter) == PackageDeliveryCheck.Result.READY)
	assert(CustomerFlowService.declare(visit.visit_id, CustomerVisit.Declaration.TAKEN))
	assert(not visit.settlement_committed)
	ECS.world.process(visit.definition.receiving_seconds, "GamePlay")
	ECS.world.process(visit.definition.leaving_seconds, "GamePlay")
	assert(state.result == ChallengeResult.Type.SUCCESS)
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(visit.finished and visit.settlement_committed)
	assert(visit.challenge_satisfaction_delta == 10)
	await get_tree().process_frame
	assert(not (hud.get_node("GazeWarning") as Label).visible)
	_level.free()
	ECS.world = null
	print("Challenge gaze actual dialogue camera warning physical service departure and cleanup smoke PASS")
	get_tree().quit.call_deferred()
