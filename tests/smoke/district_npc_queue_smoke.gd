extends Node
## Второй день основной сцены: две подготовленные личности, обычное движение и конечное ожидание света.

const MAX_FRAMES: int = 9000
const READY_RADIUS: float = 6.0

var _failed: bool = false
var _level: Node3D
var _cycle: C_DayCycle
var _flow: C_CustomerFlow

#region Сценарий второго дня
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_level = (load("res://content/scenes/main_level.tscn") as PackedScene).instantiate() as Node3D
	_level.set("autosave_path", "")
	add_child(_level)
	_cycle = DayPhaseService.current()
	_flow = CustomerFlowService.current()
	_cycle.day_index = 2
	_cycle.minimum_shift_seconds = 0.0
	DistrictPopulationService.prepare_morning(2)
	for frame: int in MAX_FRAMES:
		await get_tree().physics_frame
		if _flow.visits.size() == 5:
			break
	_check(_flow.visits.size() == 5, "day two has five real shipment cases")
	for parcel: Entity in ECS.world.query.with_all([C_Package]).execute():
		_check((parcel.get_component(C_Package) as C_Package).delivery_day == 2, "day two physical box")
		_check(PackageRegistrationService.register_package(parcel).outcome == PackageScanResult.Outcome.REGISTERED, "registration")
	_check_authored_service_light()

	var routes: NpcServiceRoutes = _level.get_node(DistrictPopulationService.current().definition.service_routes_path) as NpcServiceRoutes
	_check(routes != null, "explicit scene routes")
	for route_index: int in 2:
		for point_index: int in 2:
			var point: Node3D = routes.point_for(route_index, point_index)
			var map: RID = _level.get_world_3d().navigation_map
			_check(NavigationServer3D.map_get_closest_point(map, point.global_position).distance_to(point.global_position) < 0.7, "authored walking point on existing navmesh")
	for frame: int in MAX_FRAMES:
		await get_tree().physics_frame
		if _nearby_recipients() == 3:
			break
	_check(_nearby_recipients() == 3, "morning prepares current and two different nearby recipients")
	_cycle.phase = C_DayCycle.Phase.DAY
	var last_arrival: float = 0.0
	var arrived: int = 0
	var light_deferred: bool = false
	var previous_departure: int = 0
	for frame: int in MAX_FRAMES:
		await get_tree().physics_frame
		for candidate: Entity in ECS.world.query.with_all([C_CustomerAgent]).execute():
			var agent: C_CustomerAgent = candidate.get_component(C_CustomerAgent) as C_CustomerAgent
			if candidate.has_component(C_Death) or agent.phase not in [C_CustomerAgent.Phase.WAITING, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE, C_CustomerAgent.Phase.DIALOGUE]:
				continue
			var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
			var wait_seconds: float = float(Engine.get_physics_frames() - previous_departure) / float(Engine.physics_ticks_per_second) if previous_departure > 0 else 0.0
			print("Second day arrival ", visit.customer_id, " wait=", snappedf(wait_seconds, 0.01))
			arrived += 1
			last_arrival = agent.elapsed
			NpcServiceRole.finish_appearance(candidate as E_DistrictNpc, visit)
			previous_departure = Engine.get_physics_frames()
		for visit: CustomerVisit in _flow.visits:
			var person: NpcRecord = DistrictPopulationService.person_for(visit.customer_id)
			if visit.deferred_day == 2 and person.profile.rule_for(DEF_NpcTrait.Kind.LIGHT_AVERSION) != null:
				light_deferred = true
				_check(visit.actual == CustomerVisit.Actual.NOT_RESOLVED and visit.declaration == CustomerVisit.Declaration.NONE, "light timeout does not fake delivery or loss")
		if light_deferred and CustomerFlowService.actionable_remaining(_flow, 2) == 0:
			break
	_check(arrived >= 2, "available recipients reach the counter by ordinary movement")
	_check(light_deferred, "last light-averse case leaves finite wait")
	_check(CustomerFlowService.actionable_remaining(_flow, 2) == 0, "no required unreachable case remains")
	_check(DayPhaseService.finish_blockers(_cycle).is_empty(), "second day can finish")
	for visit: CustomerVisit in _flow.visits:
		_check(visit.finished, "every real case ends or is explicitly deferred")
		_check(visit.actual == CustomerVisit.Actual.NOT_RESOLVED and visit.declaration == CustomerVisit.Declaration.NONE, "routing smoke does not fabricate issuance or loss")
		_check(not visit.settlement_committed and visit.money_delta == 0, "routing smoke does not fabricate payment")
		if visit.deferred_day == 2:
			_check(not visit.defer_reason.is_empty() and visit.next_followup_day == 3, "unavailable case retains reason and next day")
		print("Second day case ", visit.customer_id, " finished=", visit.finished, " deferred=", visit.deferred_day, " reason=", visit.defer_reason)
	print("Second day last service elapsed=", last_arrival)
	_level.free()
	ECS.world = null
	print("District second-day queue smoke ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)

func _check_authored_service_light() -> void:
	var config: DEF_District = DistrictPopulationService.current().definition
	var zone: NpcLightZone = _level.get_node("LightZones/RoomClient") as NpcLightZone
	var view: CircuitLightView = zone.get_node(zone.flicker_view_path) as CircuitLightView
	var sample: Vector3 = CustomerFlowService.counter().waiting_position() + Vector3.UP
	_check(zone.contains_point(sample), "authored light volume covers service counter")
	_check(LightCircuitService.set_by_id(config.service_light_circuit, false), "authored switch disables service light")
	_check(NpcLightingService.exposure_at(sample) == config.ambient_light, "switch-off changes authored illumination")
	_check(LightCircuitService.set_by_id(config.service_light_circuit, true), "authored switch enables service light")
	_check(NpcLightingService.exposure_at(sample) > config.ambient_light, "switch-on changes authored illumination")
	_check(LightCircuitService.flicker(config.service_light_circuit, config.service_flicker_seconds, LightFlickerRequest.DEFAULT_INTERVAL_SECONDS, &"smoke/light"), "actual service lamps receive flicker")
	view._process(LightFlickerRequest.DEFAULT_INTERVAL_SECONDS * 1.1)
	_check(not zone.is_lit() and zone.is_logically_lit(), "dark pulse preserves logical switch state")
	_check(NpcLightingService.exposure_at(sample, [], null, true) > config.ambient_light, "dark pulse does not permit light-averse entry")
	LightCircuitService.stop_flicker(config.service_light_circuit, &"smoke/light")
	view._process(0.0)
	_check(zone.is_lit(), "explicit flicker cancellation restores steady light")

func _nearby_recipients() -> int:
	var count: int = 0
	var station: E_DeliveryCounter = CustomerFlowService.counter()
	for person: NpcRecord in DistrictPopulationService.current().people:
		var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
		if body != null and body.has_component(C_CustomerAgent) and body.global_position.distance_to(station.entry_position()) < READY_RADIUS:
			count += 1
	return count

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("District second-day queue smoke: " + message)
#endregion
