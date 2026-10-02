extends Node
## Actual dialogue acknowledgement, switch input, timeout, arrival/departure and debug HUD.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 900
const UI_WAIT_FRAMES: int = 32
const LIGHT_OFF_FIXTURE: DEF_Challenge = preload("res://content/definitions/gameplay/challenges/def_challenge_light_off.tres")

var _level: Node = null
var _actor: Entity = null
var _escalations: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate()
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	_actor = _level.get_node("Entityes/Player") as Entity
	(_actor as Node as RigidBody3D).freeze = true
	var receiver: S_CustomerChallengeOutcome = _level.get_node("World/Systems/GamePlay/S_CustomerChallengeOutcome") as S_CustomerChallengeOutcome
	receiver.escalation_requested.connect(_on_escalation)
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break
	var books: Entity = CustomerFlowService.parcel_for("base_supply:1:books")
	# The default Ordinary now has no challenge. This bounded fixture still covers Light Off.
	var flow: C_CustomerFlow = CustomerFlowService.current()
	for visit: CustomerVisit in flow.visits:
		if visit.definition.key == &"ordinary":
			visit.definition = visit.definition.duplicate(true) as DEF_Customer
			visit.definition.challenge = LIGHT_OFF_FIXTURE
	assert(PackageRegistrationService.register_package(books).outcome == PackageScanResult.Outcome.REGISTERED)
	var cycle: C_DayCycle = DayPhaseService.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))
	ECS.world.process(FRAME_DELTA, "GamePlay")
	var first: E_Customer = await _wait_for_customer()
	var first_state: C_Challenge = first.get_component(C_Challenge) as C_Challenge
	await _show_demand(first)
	ECS.world.process(first_state.definition.timeout_seconds + FRAME_DELTA, "GamePlay")
	assert(first_state.phase == C_Challenge.Phase.INACTIVE, "Reading the demand must not consume the timer")
	# Closing before acknowledging keeps the demand available for the next conversation.
	(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP)[0] as CustomerDialoguePanel).close_dialogue()
	await get_tree().process_frame
	assert(not first_state.consumed)
	await _start_after_demand(first)
	assert(first_state.phase == C_Challenge.Phase.ACTIVE)
	assert(InteractionControlFocus.current(_actor) != InteractionControlFocus.Priority.MODAL)
	await _use_switch()
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(first_state.result == ChallengeResult.Type.SUCCESS)
	var first_visit: CustomerVisit = _visit(first)
	assert(first_visit.challenge_satisfaction_delta == 10)
	assert(_escalations == 0)
	assert(CustomerFlowService.deny(first_visit.visit_id))
	ECS.world.process(first_visit.definition.leaving_seconds, "GamePlay")
	var glass: Entity = CustomerFlowService.parcel_for("base_supply:1:glass")
	assert(PackageRegistrationService.register_package(glass).outcome == PackageScanResult.Outcome.REGISTERED)
	var second: E_Customer = await _wait_for_customer()
	await _start_after_demand(second)
	var second_state: C_Challenge = second.get_component(C_Challenge) as C_Challenge
	assert((second_state.definition.condition as DEF_LightChallengeCondition).required_enabled)
	ECS.world.process(second_state.definition.timeout_seconds, "GamePlay")
	assert(second_state.result == ChallengeResult.Type.FAILURE)
	assert(_visit(second).challenge_satisfaction_delta == -30)
	assert(_escalations == 1)
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(_escalations == 1)
	var second_visit: CustomerVisit = _visit(second)
	assert(CustomerFlowService.deny(second_visit.visit_id))
	# R17 now executes aggression. Let its authored bounded conflict end before exit.
	ECS.world.process(second_visit.definition.aggressive_seconds, "GamePlay")
	ECS.world.process(second_visit.definition.leaving_seconds, "GamePlay")
	var clothes: Entity = CustomerFlowService.parcel_for("base_supply:1:clothes")
	assert(PackageRegistrationService.register_package(clothes).outcome == PackageScanResult.Outcome.REGISTERED)
	var third: E_Customer = await _wait_for_customer()
	var third_state: C_Challenge = third.get_component(C_Challenge) as C_Challenge
	assert(third_state.phase == C_Challenge.Phase.ACTIVE, "Arrival variant starts without a dialogue")
	assert(third_state.definition.completion == DEF_Challenge.Completion.UNTIL_DEPARTURE)
	assert(ChallengePresentation.text_for(_actor).contains("до ухода"))
	await _use_switch()
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(third_state.phase == C_Challenge.Phase.ACTIVE, "Correct light must not end the visit challenge early")
	await get_tree().process_frame
	var debug: Label3D = third.get_node("DebugStatus") as Label3D
	assert(debug.text.contains("Задача:"))
	assert(debug.text.contains("Свет:"))
	assert(debug.text.contains("До физического ухода"))
	assert(CustomerFlowService.voluntary_refuse(third))
	ECS.world.process(FRAME_DELTA, "GamePlay")
	assert(third_state.phase == C_Challenge.Phase.ACTIVE, "Walking away still belongs to the visit")
	ECS.world.process(_visit(third).definition.leaving_seconds, "GamePlay")
	assert(third_state.result == ChallengeResult.Type.SUCCESS)
	assert(_visit(third).challenge_result == &"success")
	assert(_escalations == 1)
	_level.free()
	ECS.world = null
	print("Challenge light demand switch success timeout visit-lifetime and debug HUD smoke PASS")
	get_tree().quit.call_deferred()


func _wait_for_customer() -> E_Customer:
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		var customer: E_Customer = CustomerFlowService.waiting_customer()
		if customer != null:
			return customer
	for entity: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var agent: C_CustomerAgent = entity.get_component(C_CustomerAgent) as C_CustomerAgent
		var intent: C_NpcIntent = entity.get_component(C_NpcIntent) as C_NpcIntent
		print("Customer wait diagnostic: ", agent.visit_id, " phase=", agent.phase, " elapsed=", agent.elapsed, " position=", (entity as Node as Node3D).global_position, " target=", intent.move_position, " arrived=", intent.arrived, " pending=", intent.navigation_pending, " blocked=", intent.navigation_blocked)
	assert(false, "Customer must reach service phase")
	return null


func _show_demand(customer: E_Customer) -> void:
	assert(CustomerDialogueService.start(_actor, customer))
	for frame: int in UI_WAIT_FRAMES:
		await get_tree().process_frame
		var panels: Array[Node] = get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP)
		if panels.is_empty():
			continue
		for node: Node in panels[0].find_children("*", "RichTextLabel", true, false):
			if (node as RichTextLabel).text.contains("свет"):
				assert(InteractionControlFocus.current(_actor) == InteractionControlFocus.Priority.MODAL)
				return
	assert(false, "Compiled dialogue must show the actual challenge demand")


func _start_after_demand(customer: E_Customer) -> void:
	await _show_demand(customer)
	var panel: Node = get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP)[0]
	var continued: bool = false
	for node: Node in panel.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text == "Продолжить" and button.visible and not button.disabled:
			button.pressed.emit()
			continued = true
			break
	assert(continued)
	for frame: int in UI_WAIT_FRAMES:
		await get_tree().process_frame
		if get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).is_empty():
			return
	assert(false, "Demand acknowledgement must close modal dialogue and restore control")


func _use_switch() -> void:
	var light_switch: Entity = _level.get_node("Entityes/LightSwitch") as Entity
	var position: Vector3 = (light_switch as Node as Node3D).global_position
	var ray: RayCast3D = GrabService.interaction_raycast(_actor)
	ray.global_position = position + Vector3.RIGHT * 1.5
	ray.look_at(position)
	for frame: int in 2:
		await get_tree().physics_frame
	var interactor: C_Interactor = _actor.get_component(C_Interactor) as C_Interactor
	interactor.target = InteractionTargetingService.find_target(_actor, interactor)
	assert(interactor.target == light_switch)
	var controller: C_Controller = _actor.get_component(C_Controller) as C_Controller
	controller.input_tick += 1
	controller.interact_pressed = true
	ECS.world.process(FRAME_DELTA, "Interaction")
	controller.interact_pressed = false


func _visit(customer: E_Customer) -> CustomerVisit:
	return CustomerFlowService.find_visit((customer.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id)


func _on_escalation(_customer: Entity, actor: Entity, event: ChallengeResolution) -> void:
	assert(actor == _actor)
	assert(event.result == ChallengeResult.Type.FAILURE)
	_escalations += 1
