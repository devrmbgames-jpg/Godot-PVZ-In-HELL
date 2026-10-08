extends Node
## Проверяет короткий свободный подход подготовленных NPC; особенности покрывает smoke второго дня.

## Ограничивает начальный подход; короткий переход подготовленной очереди проверяется отдельно.
const MAX_WAIT_FRAMES: int = 9000
const MAX_PREPARED_WAIT_SECONDS: float = 10.0
const PREPARED_RECIPIENT_COUNT: int = 3
const NEARBY_RADIUS: float = 6.0

var _failed: bool = false
var _level: Node3D = null

#region Связный сценарий основной сцены
func _ready() -> void:
	_run.call_deferred()

## Проверяет реальные заказы и три последовательных подготовленных получателя без опасностей.
func _run() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	_level.set("autosave_path", "")
	add_child(_level)
	_prepare_clear_route()
	# Проверка свободного подхода не провоцирует NPC неподвижным взглядом игрока.
	var neutral_camera: Camera3D = Camera3D.new()
	add_child(neutral_camera)
	neutral_camera.position = Vector3.UP * 100.0
	neutral_camera.current = true
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
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
	var prepared_identities: Array[StringName] = _stage_prepared_recipients()
	for frame: int in 3:
		await get_tree().physics_frame
	_check(_nearby_recipients() == PREPARED_RECIPIENT_COUNT, "current and two distinct recipients are staged nearby")
	_check(prepared_identities.size() == PREPARED_RECIPIENT_COUNT, "exactly three distinct identities are prepared")
	_check(ECS.world.query.with_all([C_Hazard, C_ToxicArea]).execute().is_empty(), "clear route has no active hazard")
	_check(flow.visits.size() == 5, "long morning does not append another supply")

	cycle.phase = C_DayCycle.Phase.DAY
	var identities: Array[StringName] = []
	var previous_departure: int = 0
	for appearance: int in PREPARED_RECIPIENT_COUNT:
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
		var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
		_check(not identities.has(visit.customer_id), "next recipient is a different living person")
		_check(prepared_identities.has(visit.customer_id), "arrival belongs to the originally prepared queue")
		identities.append(visit.customer_id)
		if previous_departure > 0:
			var wait_seconds: float = float(Engine.get_physics_frames() - previous_departure) / float(Engine.physics_ticks_per_second)
			print("Prepared recipient wait: ", snappedf(wait_seconds, 0.01), " sec")
			_check(wait_seconds <= MAX_PREPARED_WAIT_SECONDS, "prepared recipient arrives within ten seconds on clear route")
		print("Counter arrival ", appearance + 1, ": ", visit.customer_id, " at ", recipient.global_position)
		_check(ECS.world.query.with_all([C_CustomerAgent]).execute().size() <= PREPARED_RECIPIENT_COUNT, "current and at most two prepared roles")
		_check(_counter_reservations() == 1, "only one recipient reserves the counter")
		NpcServiceRole.finish_appearance(recipient, visit)
		previous_departure = Engine.get_physics_frames()
	_check(identities.size() == PREPARED_RECIPIENT_COUNT, "three distinct recipients after release")
	for visit: CustomerVisit in flow.visits:
		print("Clear-route case ", visit.customer_id, " finished=", visit.finished, " dead=", visit.customer_dead, " reason=", visit.defer_reason)
		_check(visit.deferred_day == 0, "clear route does not defer a prepared recipient")

	var dialogue: DialogueResource = load("res://content/domains/customers/dialogue/customer_service.dialogue") as DialogueResource
	_check(dialogue != null and dialogue.cues.has("home_request") and dialogue.cues.has("home_declined"), "compiled customer delivery branches")
	var street: DialogueResource = load("res://content/domains/npc/dialogue/npc_street.dialogue") as DialogueResource
	_check(street != null and street.cues.has("delivery_request") and street.cues.has("delivery_declined"), "compiled street delivery branches")
	var aura: DEF_ToxicArea = load("res://content/domains/hazards/definitions/def_npc_fire_aura.tres") as DEF_ToxicArea
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
		print(agent.visit_id, " phase=", agent.phase, " elapsed=", agent.elapsed, " pos=", body.global_position, " dist=", intent.distance_to_target, " moving=", intent.movement_active, " reachable=", route.reachable, " owner=", decision.active_behavior)

func _counter_reservations() -> int:
	var count: int = 0
	for entity: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		for link: Relationship in entity.relationships:
			if link.relation is R_NpcServiceAt:
				count += 1
	return count

func _nearby_recipients() -> int:
	var count: int = 0
	var station: E_DeliveryCounter = CustomerFlowQueries.counter()
	for entity: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
		var spatial: Node3D = entity as Node as Node3D
		if spatial != null and spatial.global_position.distance_to(station.entry_position()) < NEARBY_RADIUS:
			count += 1
	return count

func _prepare_clear_route() -> void:
	# Профили меняются до первого physics-кадра: уже созданная аура не исчезает от очистки rules.
	for person: NpcRecord in NpcPopulationQueries.current().people:
		person.profile = person.profile.duplicate() as DEF_NpcProfile
		person.profile.rules = []

func _stage_prepared_recipients() -> Array[StringName]:
	var station: E_DeliveryCounter = CustomerFlowQueries.counter()
	var routes: NpcServiceRoutes = _level.get_node(NpcPopulationQueries.current().definition.service_routes_path) as NpcServiceRoutes
	var index: int = 0
	var identities: Array[StringName] = []
	for visit: CustomerVisit in CustomerFlowQueries.current().visits:
		var recipient: E_DistrictNpc = CustomerFlowQueries.customer_for(visit.visit_id) as E_DistrictNpc
		if recipient == null:
			continue
		# Этот smoke изолирует короткий свободный подход уже подготовленных NPC.
		var point: Vector3 = station.entry_position() if index == 0 else routes.point_for(index - 1, 0).global_position
		recipient.place_at(point)
		identities.append(visit.customer_id)
		index += 1
	return identities

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("NPC service backlog smoke: " + message)
#endregion
