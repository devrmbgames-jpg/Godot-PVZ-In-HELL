extends Node
## Сценарий физического пути к авторской кабине осмотра и возврата коробки через NavigationAgent.

const MAIN: PackedScene = preload("res://content/scenes/main_level.tscn")
const FRAME_DELTA: float = 1.0 / 60.0
const MAX_FRAMES: int = 2400
const INSPECTION_SECONDS: float = 1.0

var _level: Node

#region Smoke lifecycle
func _ready() -> void:
	_run.call_deferred()


## Creates the real host and releases it after the awaited scenario has released its local state.
func _run() -> void:
	_level = MAIN.instantiate()
	_level.set("autosave_path", "")
	add_child(_level)
	# The native route/parcel fixture isolates all district footsteps from accelerated playback.
	for feedback: CharacterFeedback in _level.find_children("*", "CharacterFeedback", true, false):
		feedback.footsteps_enabled = false
	_level.set_physics_process(false)
	(_level.get_node("Entityes/Player") as Node).set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame

	await _exercise_inspection()
	_level.free()
	_level = null
	await get_tree().process_frame
	print("Customer inspection actual main native booth walk parcel return refusal smoke PASS")
	get_tree().quit.call_deferred()
#endregion

#region Native inspection scenario
func _exercise_inspection() -> void:
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	flow.schedule = null
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"smoke/inspection"
	visit.package_id = "smoke/inspection/parcel"
	visit.definition = DEF_Customer.new()
	visit.definition.private_inspection = true
	visit.definition.inspection_seconds = INSPECTION_SECONDS
	visit.definition.inspection_keep_probability = 0.0
	visit.definition.max_followup_visits = 0
	visit.started = true
	visit.visit_count = 1
	flow.visits = [visit]

	var counter: E_DeliveryCounter = CustomerFlowQueries.counter()
	var customer: E_NpcCharacter = (load("res://content/domains/customers/entities/customer.tscn") as PackedScene).instantiate() as E_NpcCharacter
	# Навигационный прогон с фиксированным FPS опережает аудиомикшер; звук проверяет владелец отдельно.
	(customer.get_node("CharacterFeedback") as CharacterFeedback).footsteps_enabled = false
	var body: RigidBody3D = customer as Node as RigidBody3D
	body.position = counter.waiting_position()
	_level.add_child(body)
	EntityCompositionFixture.register(ECS.world, customer, false)

	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.visit_id = visit.visit_id
	agent.phase = C_CustomerAgent.Phase.WAITING_FOR_PACKAGE
	var parcel: E_Package = (load("res://content/domains/packages/entities/test_bread.tscn") as PackedScene).instantiate() as E_Package
	parcel.package_id = visit.package_id
	(parcel as Node as RigidBody3D).position = body.position + Vector3(0, 1, 0)
	_level.add_child(parcel)
	EntityCompositionFixture.register(ECS.world, parcel, false)
	(parcel.get_component(C_PackageState) as C_PackageState).registration = C_PackageState.Registration.REGISTERED
	CustomerParcelAssignment.bind_parcel(customer, visit)
	var delivery_result: PackageDeliveryCheck.Result = CustomerFlowService._resolve_delivery(
		customer, visit, parcel, null,
	)
	assert(delivery_result == PackageDeliveryCheck.Result.READY)
	assert(agent.phase == C_CustomerAgent.Phase.GOING_TO_BOOTH)

	var visited: bool = false
	for frame: int in MAX_FRAMES:
		ECS.world.process(FRAME_DELTA, "Physics")
		GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
		await get_tree().physics_frame
		if agent.phase == C_CustomerAgent.Phase.INSPECTING:
			visited = true
			var stored: Relationship = PhysicalSlotService.relationship(parcel)
			assert(stored != null and (stored.relation as R_StoredIn).applied)
			assert((parcel as Node as Node3D).global_position.distance_to(body.global_position) < 2.0)
		if visit.actual != CustomerVisit.Actual.NOT_RESOLVED:
			break
	if not visited or visit.actual == CustomerVisit.Actual.NOT_RESOLVED:
		var intent: C_NpcIntent = customer.get_component(C_NpcIntent) as C_NpcIntent
		print("Inspection route diagnostic: phase=", agent.phase, " position=", body.global_position, " target=", intent.move_position, " blocked=", intent.navigation_blocked, " distance=", intent.distance_to_target, " path=", customer.navigation_agent.get_current_navigation_path())
	assert(visited, "Actual NavigationAgent must reach the authored private booth")
	assert(visit.actual == CustomerVisit.Actual.CUSTOMER_REFUSED, "Customer must return and make the authored choice")
	assert(body.global_position.distance_to(counter.waiting_position()) < 0.5)
	assert(PhysicalSlotService.relationship(parcel) == null)
	assert(not (parcel as Node as RigidBody3D).freeze)
#endregion
