extends Node
## R12 lifecycle smoke: an active modal dialogue must release itself when service ends or NPC dies.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 300

var _level: Node = null
var _cycle: C_DayCycle = null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate()
	add_child(_level)
	_level.set_physics_process(false)
	_cycle = DayPhaseService.current()

	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break
	assert(ECS.world.query.with_all([C_Package]).execute().size() == 8)

	var actor: Entity = _level.get_node("Entityes/Player") as Entity
	(actor as Node as RigidBody3D).freeze = true
	var books: Entity = CustomerFlowService.parcel_for("base_supply:1:books")
	var glass: Entity = CustomerFlowService.parcel_for("base_supply:1:glass")
	assert(PackageRegistrationService.register_package(books).outcome == PackageScanResult.Outcome.REGISTERED)
	_transition(DayTransitionRequest.Kind.START_SHIFT)

	var leaving_customer: E_Customer = await _wait_for_customer()
	var leaving_agent: C_CustomerAgent = (
		leaving_customer.get_component(C_CustomerAgent) as C_CustomerAgent
	)
	assert(CustomerDialogueService.start(actor, leaving_customer))
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).size() == 1)
	assert(CustomerFlowService.deny(leaving_agent.visit_id))
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).is_empty())

	var leaving_visit: CustomerVisit = CustomerFlowService.find_visit(leaving_agent.visit_id)
	ECS.world.process(leaving_visit.definition.leaving_seconds, "GamePlay")
	assert(PackageRegistrationService.register_package(glass).outcome == PackageScanResult.Outcome.REGISTERED)
	var dead_customer: E_Customer = await _wait_for_customer()
	assert(CustomerDialogueService.start(actor, dead_customer))
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).size() == 1)
	dead_customer.add_component(C_Death.new())
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).is_empty())

	_level.free()
	ECS.world = null
	print("R12 customer dialogue lifecycle smoke PASS")
	get_tree().quit()


func _transition(kind: DayTransitionRequest.Kind) -> void:
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = kind
	request.expected_day = _cycle.day_index
	request.expected_phase = _cycle.phase
	assert(DayPhaseService.submit(request))
	ECS.world.process(FRAME_DELTA, "GamePlay")


func _wait_for_customer() -> E_Customer:
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		var customer: E_Customer = CustomerFlowService.waiting_customer()
		if customer != null:
			return customer
	assert(false, "Customer must reach WAITING_FOR_PACKAGE within frame budget")
	return null
