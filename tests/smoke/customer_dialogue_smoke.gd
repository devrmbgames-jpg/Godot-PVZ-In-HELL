extends Node
## Сценарий закрытия модального диалога при завершении обслуживания или смерти NPC.

const FRAME_DELTA: float = 1.0 / 60.0
const WAIT_FRAMES: int = 300

var _level: Node = null
var _cycle: C_DayCycle = null


#region Сценарий закрытия диалога
func _ready() -> void:
	_run.call_deferred()


## Проверяет освобождение модального диалога в историческом сценарии поставки восьми коробок.
func _run() -> void:
	var scene: PackedScene = load("res://content/scenes/main_level.tscn") as PackedScene
	_level = scene.instantiate()
	add_child(_level)
	_level.set_physics_process(false)
	_cycle = DayPhaseQueries.current()

	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		if ECS.world.query.with_all([C_Package]).execute().size() == 8:
			break

	assert(ECS.world.query.with_all([C_Package]).execute().size() == 8)

	var actor: Entity = _level.get_node("Entityes/Player") as Entity
	(actor as Node as RigidBody3D).freeze = true
	var books: Entity = PackageQueries.find_live_package("base_supply:1:books")
	var glass: Entity = PackageQueries.find_live_package("base_supply:1:glass")
	assert(PackageRegistrationService.register_package(books).outcome == PackageScanResult.Outcome.REGISTERED)
	_transition(DayTransitionRequest.Kind.START_SHIFT)

	var leaving_customer: E_NpcCharacter = await _wait_for_customer()
	var leaving_agent: C_CustomerAgent = (
		leaving_customer.get_component(C_CustomerAgent) as C_CustomerAgent
	)
	assert(CustomerDialogueService.request_open(actor, leaving_customer))
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).size() == 1)
	assert(CustomerFlowService.deny(leaving_agent.visit_id))
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).is_empty())

	var leaving_visit: CustomerVisit = CustomerFlowQueries.find_visit(leaving_agent.visit_id)
	ECS.world.process(leaving_visit.definition.leaving_seconds, "GamePlay")
	assert(PackageRegistrationService.register_package(glass).outcome == PackageScanResult.Outcome.REGISTERED)
	var dead_customer: E_NpcCharacter = await _wait_for_customer()
	assert(CustomerDialogueService.request_open(actor, dead_customer))
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).size() == 1)
	dead_customer.add_component(C_Death.new())
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group(CustomerDialogueService.ACTIVE_GROUP).is_empty())

	_level.free()
	ECS.world = null
	print("R12 customer dialogue lifecycle smoke PASS")
	get_tree().quit()


#endregion

#region Переход фаз и ожидание клиента
func _transition(kind: DayTransitionRequest.Kind) -> void:
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = kind
	request.expected_day = _cycle.day_index
	request.expected_phase = _cycle.phase
	assert(DayPhaseService.submit(request))
	ECS.world.process(FRAME_DELTA, "GamePlay")


func _wait_for_customer() -> E_NpcCharacter:
	for frame: int in WAIT_FRAMES:
		ECS.world.process(FRAME_DELTA, "GamePlay")
		await get_tree().physics_frame
		var customer: E_NpcCharacter = CustomerFlowQueries.waiting_customer()
		if customer != null:
			return customer

	assert(false, "Customer must reach WAITING_FOR_PACKAGE within frame budget")
	return null

#endregion
