extends Node
## Проверяет короткий свободный подход подготовленных NPC; особенности покрывает smoke второго дня.

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
	_level.set("autosave_path", "")
	add_child(_level)
	# Проверка свободного подхода не провоцирует NPC неподвижным взглядом игрока.
	var neutral_camera: Camera3D = Camera3D.new()
	add_child(neutral_camera)
	neutral_camera.position = Vector3.UP * 100.0
	neutral_camera.current = true
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
	_stage_prepared_recipients()
	for frame: int in 3:
		await get_tree().physics_frame
	_check(_nearby_recipients() == 3, "three recipients finish their morning approach")
	_check(flow.visits.size() == 5, "long morning does not append another supply")

	cycle.phase = C_DayCycle.Phase.DAY
	var identities: Array[StringName] = []
	var previous_departure: int = 0
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
		if previous_departure > 0:
			var wait_seconds: float = float(Engine.get_physics_frames() - previous_departure) / float(Engine.physics_ticks_per_second)
			print("Prepared recipient wait: ", snappedf(wait_seconds, 0.01), " sec")
			_check(wait_seconds <= 10.0, "prepared recipient arrives within ten seconds on clear route")
		print("Counter arrival ", appearance + 1, ": ", visit.customer_id, " at ", recipient.global_position)
		_check(ECS.world.query.with_all([C_CustomerAgent]).execute().size() <= 3, "current and at most two prepared roles")
		_check(_counter_reservations() == 1, "only one recipient reserves the counter")
		if appearance == 1:
			recipient.add_component(C_Death.new())
		else:
			NpcServiceRole.finish_appearance(recipient, visit)
		previous_departure = Engine.get_physics_frames()
	_check(identities.size() == 3, "three distinct recipients after release and death")
	for visit: CustomerVisit in flow.visits:
		print("Clear-route case ", visit.customer_id, " finished=", visit.finished, " dead=", visit.customer_dead, " reason=", visit.defer_reason)

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
		if entity.has_component(C_Death) or route == null or decision == null:
			continue
		print(agent.visit_id, " phase=", agent.phase, " elapsed=", agent.elapsed, " pos=", body.global_position, " goal=", intent.move_position, " dist=", intent.distance_to_target, " moving=", intent.movement_active, " reachable=", route.reachable, " point=", route.point_index, " points=", route.points, " owner=", decision.active_behavior)

func _counter_reservations() -> int:
	var count: int = 0
	for entity: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		for link: Relationship in entity.relationships:
			if link.relation is R_NpcServiceAt:
				count += 1
	return count

func _nearby_recipients() -> int:
	var count: int = 0
	var station: E_DeliveryCounter = CustomerFlowService.counter()
	for entity: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var spatial: Node3D = entity as Node as Node3D
		if spatial != null and spatial.global_position.distance_to(station.entry_position()) < 6.0:
			count += 1
	return count

func _stage_prepared_recipients() -> void:
	var station: E_DeliveryCounter = CustomerFlowService.counter()
	var routes: NpcServiceRoutes = _level.get_node(DistrictPopulationService.current().definition.service_routes_path) as NpcServiceRoutes
	var index: int = 0
	for visit: CustomerVisit in CustomerFlowService.current().visits:
		var recipient: E_DistrictNpc = CustomerFlowService.customer_for(visit.visit_id) as E_DistrictNpc
		if recipient == null:
			continue
		var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
		person.profile = person.profile.duplicate() as DEF_NpcProfile
		person.profile.rules = []
		# Этот smoke изолирует короткий свободный подход уже подготовленных NPC.
		var point: Vector3 = station.entry_position() if index == 0 else routes.point_for(index - 1, 0).global_position
		recipient.place_at(point)
		index += 1

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("NPC service backlog smoke: " + message)
#endregion
