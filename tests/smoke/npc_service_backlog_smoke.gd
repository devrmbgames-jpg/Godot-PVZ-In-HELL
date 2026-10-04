extends Node
## Проверяет реальную поставку и последовательные визиты в основной сцене без рендера.

## Допуск включает авторские 120 секунд подхода по протяжённому статичному району.
const MAX_WAIT_FRAMES: int = 9000

var _failed: bool = false
var _level: Node3D = null

#region Связный сценарий основной сцены
func _ready() -> void:
	_run.call_deferred()

## Проверяет пять реальных заказов и три последовательных получателя после ухода и смерти.
func _run() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	add_child(_level)
	var flow: C_CustomerFlow = CustomerFlowService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	flow.schedule = flow.schedule.duplicate() as DEF_CustomerSchedule
	flow.schedule.arrival_interval_seconds = 0.0
	for frame: int in MAX_WAIT_FRAMES:
		await get_tree().physics_frame
		if flow.visits.size() == 5:
			break
	_check(flow.visits.size() == 5, "morning creates five real cases; actual=%d" % flow.visits.size())
	_check(ECS.world.query.with_all([C_Package]).execute().size() == 5, "five physical boxes")
	for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
		_check(PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.REGISTERED, "physical box registration")
	for frame: int in 30:
		await get_tree().physics_frame
	_check(flow.visits.size() == 5, "long morning does not append another supply")

	cycle.phase = C_DayCycle.Phase.DAY
	var identities: Array[StringName] = []
	for appearance: int in 3:
		var recipient: E_DistrictNpc = null
		for frame: int in MAX_WAIT_FRAMES:
			await get_tree().physics_frame
			if frame % 600 == 0:
				_trace_service(appearance, frame)
			for entity: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
				var service: C_CustomerAgent = entity.get_component(C_CustomerAgent) as C_CustomerAgent
				if not entity.has_component(C_Death) and service.phase in [C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE, C_CustomerAgent.Phase.DIALOGUE]:
					recipient = entity as E_DistrictNpc
					break
			if recipient != null:
				break
		if recipient == null:
			_check(false, "recipient %d arrives" % (appearance + 1))
			break

		var agent: C_CustomerAgent = recipient.get_component(C_CustomerAgent) as C_CustomerAgent
		var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
		_check(not identities.has(visit.customer_id), "next recipient is a different living person")
		identities.append(visit.customer_id)
		print("Counter arrival ", appearance + 1, ": ", visit.customer_id, " at ", recipient.global_position)
		_check(ECS.world.query.with_all([C_CustomerAgent]).execute().size() == 1, "only current service role waits")
		if appearance == 1:
			recipient.add_component(C_Death.new())
		else:
			NpcServiceRole.finish_appearance(recipient, visit)
	_check(identities.size() == 3, "three distinct recipients after release and death")

	var dialogue: DialogueResource = load("res://content/dialogue/customer_service.dialogue") as DialogueResource
	_check(dialogue != null and dialogue.cues.has("home_request") and dialogue.cues.has("home_declined"), "compiled customer delivery branches")
	var street: DialogueResource = load("res://content/dialogue/npc_street.dialogue") as DialogueResource
	_check(street != null and street.cues.has("delivery_request") and street.cues.has("delivery_declined"), "compiled street delivery branches")
	var aura: DEF_ToxicArea = load("res://content/definitions/gameplay/hazards/def_npc_fire_aura.tres") as DEF_ToxicArea
	_check(is_equal_approx(aura.radius, 2.25), "fire radius reduced by 25 percent")
	_level.free()
	ECS.world = null
	print("NPC service backlog smoke ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)

func _trace_service(appearance: int, frame: int) -> void:
	print("Service trace ", appearance + 1, " frame=", frame)
	for entity: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var body: E_DistrictNpc = entity as E_DistrictNpc
		var agent: C_CustomerAgent = entity.get_component(C_CustomerAgent) as C_CustomerAgent
		var intent: C_NpcIntent = entity.get_component(C_NpcIntent) as C_NpcIntent
		var route: C_NpcRoute = entity.get_component(C_NpcRoute) as C_NpcRoute
		var decision: C_NpcDecision = entity.get_component(C_NpcDecision) as C_NpcDecision
		print(agent.visit_id, " phase=", agent.phase, " elapsed=", agent.elapsed, " pos=", body.global_position, " goal=", intent.move_position, " dist=", intent.distance_to_target, " moving=", intent.movement_active, " reachable=", route.reachable, " point=", route.point_index, " points=", route.points, " owner=", decision.active_behavior)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("NPC service backlog smoke: " + message)
#endregion
