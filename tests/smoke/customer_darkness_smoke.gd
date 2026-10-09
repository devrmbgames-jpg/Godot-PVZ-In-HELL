extends Node
## Сценарий старого светового испытания в main_level: лампы, выключатель и агрессия по таймауту.

const FRAME_DELTA: float = 1.0 / 60.0
const SUPPLY_FRAMES: int = 900
const ARRIVAL_POSITION_EPSILON: float = 0.05

var _level: Node = null
var _flickers: int = 0


func _ready() -> void:
	_run.call_deferred()


func _on_flicker(event: LightFlickerRequest) -> void:
	assert(event.circuit_id == &"warehouse")
	if event.kind == LightFlickerRequest.Kind.START:
		_flickers += 1


## Запускает старую встречу светобоязненного клиента и проверяет выключатель и таймаут.
func _run() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate()
	_level.set("autosave_path", "")
	add_child(_level)
	_level.set_physics_process(false)
	var actor: Entity = _level.get_node("Entityes/Player") as Entity
	(actor as Node).set_physics_process(false)
	for frame: int in SUPPLY_FRAMES:
		GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
		await get_tree().physics_frame
		if PackageQueries.find_live_package("base_supply:1:oil") != null:
			break

	var parcel: Entity = PackageQueries.find_live_package("base_supply:1:oil")
	assert(parcel != null)
	assert(PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.REGISTERED)
	var relay: O_LightFlicker = _level.get_node("World/Systems/GamePlay/O_LightFlicker") as O_LightFlicker
	relay.flickering_light.connect(_on_flicker)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	var request: DayTransitionRequest = DayTransitionRequest.new()
	request.kind = DayTransitionRequest.Kind.START_SHIFT
	request.expected_day = cycle.day_index
	request.expected_phase = cycle.phase
	assert(DayPhaseService.submit(request))

	var first: E_NpcCharacter = null
	for frame: int in SUPPLY_FRAMES:
		GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
		await get_tree().physics_frame
		first = ECS.world.query.with_all([C_CustomerAgent]).execute_one() as E_NpcCharacter
		if first != null:
			break

	assert(first != null)
	(first as Node as RigidBody3D).freeze = true
	var agent: C_CustomerAgent = first.get_component(C_CustomerAgent) as C_CustomerAgent
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
	assert(visit.definition.key == &"light_sensitive_customer")
	assert(agent.phase == C_CustomerAgent.Phase.WAITING_FOR_DARKNESS)
	assert(not (first.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	assert(_flickers == 1)

	var station: E_DeliveryCounter = CustomerFlowQueries.counter()
	var offset: Vector3 = (first as Node as Node3D).global_position - station.entry_position()
	offset.y = 0.0
	assert(offset.length() < ARRIVAL_POSITION_EPSILON, "Stopped entrance intent must keep its horizontal position; native gravity owns Y")
	for node: Node in get_tree().get_nodes_in_group(&"warehouse_lights"):
		var light: Light3D = node as Light3D
		var view: CircuitLightView = light.get_node("CircuitLightView") as CircuitLightView
		view._process(0.16)
		assert(not light.visible)
	assert(LightCircuitService.is_enabled(&"warehouse"))
	assert(LightCircuitService.set_by_id(&"warehouse", false))
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)

	var state: C_Challenge = first.get_component(C_Challenge) as C_Challenge
	assert(state.result == ChallengeResult.Type.SUCCESS)
	assert(agent.phase == C_CustomerAgent.Phase.APPROACHING)
	assert((first.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	assert(not visit.aggressive)
	assert(CustomerFlowService.deny(visit.visit_id))
	GameTimeFixture.gameplay(ECS.world, visit.definition.leaving_seconds)
	GameTimeFixture.gameplay(ECS.world, FRAME_DELTA)
	assert(visit.finished)
	assert(LightCircuitService.set_by_id(&"warehouse", true))
	# Повторный визит за той же зарегистрированной коробкой проверяет ветку таймаута.
	var retry: CustomerVisit = CustomerVisit.new()
	retry.visit_id = &"smoke/dark-timeout"
	retry.package_id = visit.package_id
	retry.definition = visit.definition
	retry.arrival_day = cycle.day_index
	CustomerFlowQueries.current().visits.append(retry)
	assert(not CustomerFlowFixture.spawn(CustomerFlowQueries.current(), cycle), "New visit must respect the authored gap")
	GameTimeFixture.gameplay(ECS.world, CustomerFlowQueries.current().arrival_cooldown_seconds + FRAME_DELTA)

	var second: E_NpcCharacter = CustomerFlowQueries.customer_for(retry.visit_id)
	assert(second != null)
	(second as Node as RigidBody3D).freeze = true
	assert(_flickers == 2)
	state = second.get_component(C_Challenge) as C_Challenge
	assert(state.phase == C_Challenge.Phase.ACTIVE)
	GameTimeFixture.gameplay(ECS.world, state.definition.timeout_seconds)
	assert(state.result == ChallengeResult.Type.FAILURE)
	assert(not LightCircuitService.is_enabled(&"warehouse"))
	assert(retry.aggressive)
	assert((second.get_component(C_CustomerAgent) as C_CustomerAgent).phase == C_CustomerAgent.Phase.AGGRESSIVE)
	assert(CombatQueries.target_for(second) == actor)
	for node: Node in get_tree().get_nodes_in_group(&"warehouse_lights"):
		assert(not (node as Light3D).visible)
	assert(_flickers == 2)
	_level.free()
	ECS.world = null
	print("Customer darkness actual main event lamps entrance switch timeout aggression smoke PASS")
	get_tree().quit.call_deferred()
