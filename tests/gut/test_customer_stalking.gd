extends "res://tests/gut/test_district_service.gd"
## Native reserved service BT, real camera/navmesh, fixed rear contact and ordinary handoff.

const CREEPY_PROFILE: DEF_NpcArchetype = preload(
	"res://content/domains/npc/definitions/def_npc_archetype_creepy.tres"
)
const SERVICE_TREE: String = "res://content/domains/customers/ai/trees/bt_npc_service.tres"

var _rear_body: E_DistrictNpc
var _rear_person: NpcRecord
var _rear_player: E_RigidBodyCharacter
var _rear_camera: Camera3D
var _rear_agent: C_CustomerAgent
var _rear_state: C_NpcStalking
var _rear_rule: DEF_NpcStalking
var _rear_visit: CustomerVisit
var _native_map: RID = RID()
var _native_region: RID = RID()


## Exercises the synchronous structural callback boundaries of the real GECS binding.
class DuringRearBinding extends Observer:
	## Selects publication or release for this one fixture observer.
	var added: bool = true
	## Borrowed test mutation; the observer is removed before native fixture teardown.
	var on_change: Callable


	func query() -> QueryBuilder:
		return (
			q.on_relationship_added([R_CustomerStalkingTarget])
			if added
			else q.on_relationship_removed([R_CustomerStalkingTarget])
		)


	func each(_event: Variant, _body: Entity, _payload: Variant = null) -> void:
		on_change.call()


#region Real service fixture
func after_each() -> void:
	if _native_region.is_valid():
		NavigationServer3D.free_rid(_native_region)
	if _native_map.is_valid():
		NavigationServer3D.free_rid(_native_map)
	_native_region = RID()
	_native_map = RID()
	super.after_each()
	await get_tree().process_frame


func _rear_fixture(with_map: bool = true, claim_counter: bool = true) -> void:
	DayPhaseQueries.current().phase = C_DayCycle.Phase.DAY
	_rear_person = _district.people[3]
	_rear_person.profile = CREEPY_PROFILE
	_rear_person.phase_complete = true
	_rear_body = NpcPopulationQueries.body_for(_rear_person.npc_id)
	DistrictPopulationService.set_placement(_rear_person, _rear_body, NpcRecord.Placement.STREET)
	_rear_body.place_at(Vector3(0, 0, 4))
	_rear_body.freeze = true
	for index: int in _district.people.size():
		var other: E_DistrictNpc = NpcPopulationQueries.body_for(_district.people[index].npc_id)
		if other != null and other != _rear_body:
			other.place_at(Vector3(60 + index * 3, 0, 60))
			other.freeze = true
	_rear_state = _rear_body.get_component(C_NpcStalking) as C_NpcStalking
	var selected_rule: DEF_NpcStalking = NpcStalkingRules.selected_rule(_rear_person.rules_for())
	_rear_rule = selected_rule.duplicate() as DEF_NpcStalking
	_rear_rule.opportunity_probability = 1.0
	_rear_rule.success_extra_seconds = 0.0
	_rear_state.rule = _rear_rule
	(_rear_body.get_component(C_NpcAwareness) as C_NpcAwareness).player_visible = true
	var station: E_DeliveryCounter = CustomerFlowQueries.counter()
	# Keep actual counter geometry away from the isolated rear route, retaining its real markers.
	station.global_position = Vector3(30, 0, 0)
	(station.get_node("Waiting") as Node3D).global_position = Vector3.ZERO
	(station.get_node("Entry") as Node3D).global_position = Vector3(0, 0, 6)
	var physical: RigidBody3D = RigidBody3D.new()
	physical.set_script(E_RigidBodyCharacter)
	physical.freeze = true
	_rear_player = physical as Node as E_RigidBodyCharacter
	var anchor: Marker3D = Marker3D.new()
	anchor.position = Vector3(0, 1.3, 0.5)
	physical.add_child(anchor)
	_rear_player.hold_anchor = anchor
	_rear_player.head_axis_x = anchor
	_rear_camera = Camera3D.new()
	_rear_camera.position = Vector3(0, 1.5, 0)
	physical.add_child(_rear_camera)
	_rear_player.component_resources = [
		C_PlayerInputController.new(),
		C_Health.new(),
		C_Controller.new(),
		C_GrabControl.new(),
		C_CarryLoad.new(),
		C_Strength.new(),
		C_Motion.new(),
	]
	_world.add_entity(_rear_player)
	(_rear_player.get_component(C_Health) as C_Health).current = 10.0
	_rear_camera.make_current()
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_PackageLedger.new())
	session.add_component(C_Wallet.new())
	_rear_visit = _case(_rear_person, "rear-service")
	_rear_visit.definition = _rear_visit.definition.duplicate() as DEF_Customer
	_rear_visit.definition.introduction = DEF_Customer.Introduction.ANNOUNCE_ORDER
	_rear_visit.definition.dialogue_mode = DEF_Customer.DialogueMode.DIRECT
	_rear_visit.definition.approach_timeout = 20.0
	_rear_visit.payment = 20
	var record: PackageRegistrationRecord = PackageRegistrationRecord.new()
	record.package_id = _rear_visit.package_id
	record.number = 3
	(session.get_component(C_PackageLedger) as C_PackageLedger).records.append(record)
	NpcServiceRole.begin(_rear_body, _rear_person, _rear_visit, 1)
	_rear_agent = _rear_body.get_component(C_CustomerAgent) as C_CustomerAgent
	assert_true(NpcServiceRole.can_approach(_rear_body))
	if claim_counter:
		NpcServiceRole.claim_counter(_rear_body)
	var witness: S_NpcStalkingWitness = S_NpcStalkingWitness.new()
	witness.group = "rear-sample"
	_world.add_system(witness)
	var role_witness: S_CustomerStalkingWitness = S_CustomerStalkingWitness.new()
	role_witness.group = "rear-role"
	_world.add_system(role_witness)
	var clock: S_GameTime = S_GameTime.new()
	clock.group = "rear-clock"
	_world.add_system(clock)
	if with_map:
		await _rear_map()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_sense(0.0)


func _rear_map() -> void:
	var mesh: NavigationMesh = NavigationMesh.new()
	mesh.vertices = PackedVector3Array(
		[Vector3(-20, 0, -20), Vector3(-20, 0, 20), Vector3(20, 0, 20), Vector3(20, 0, -20)]
	)
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	_native_map = NavigationServer3D.map_create()
	_native_region = NavigationServer3D.region_create()
	NavigationServer3D.map_set_active(_native_map, true)
	NavigationServer3D.region_set_map(_native_region, _native_map)
	NavigationServer3D.region_set_navigation_mesh(_native_region, mesh)
	_rear_body.navigation_agent.set_navigation_map(_native_map)
	for _frame: int in 120:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(_native_map) > 0:
			break
	assert_gt(NavigationServer3D.map_get_iteration_id(_native_map), 0)


func _sense(delta: float) -> void:
	_world.process(delta, "rear-clock")
	_world.process(delta, "rear-sample")
	_world.process(delta, "rear-role")
	_world.flush_command_buffers()


func _rear_step(delta: float = 0.0) -> void:
	_run_tree(_rear_body, SERVICE_TREE, delta)


func _reach_rear() -> void:
	_rear_step()
	assert_gt(_rear_agent.stalking_sequence, 0)
	assert_true(_rear_agent.stalking_destination.is_finite())
	_rear_body.place_at(_rear_agent.stalking_destination)
	_rear_step()
	assert_true(_rear_agent.rear_contact_pending)
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)


func _rear_intent() -> C_NpcIntent:
	return _rear_body.get_component(C_NpcIntent) as C_NpcIntent


func _look_at_rear_contact() -> void:
	_rear_camera.look_at(_rear_body.global_position + Vector3.UP * NpcPerceptionService.EYE_HEIGHT)
	assert_true(
		NpcStalkingSolver.observed(_rear_body, _rear_player, _rear_body.global_position, _rear_rule)
	)
#endregion


#region Native rear strategy and fallback
func test_cooldown_expiry_alone_does_not_create_another_service_opportunity() -> void:
	await _rear_fixture()
	var previous: NpcStalkingChoice = NpcStalkingService.choose(
		_rear_person,
		_rear_rule,
		_rear_rule.service_seconds,
	)
	assert_not_null(previous)
	_rear_step()
	assert_eq(_rear_visit.stalking_visit_count, 1)
	assert_eq(_rear_agent.stalking_sequence, 0)
	var elapsed: float = _rear_rule.service_seconds + _rear_rule.retry_seconds + 0.1
	_sense(elapsed)
	_rear_step(elapsed)
	assert_eq(_rear_person.stalking_sequence, previous.sequence)
	assert_eq(_rear_agent.stalking_sequence, 0)
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.APPROACHING)
	assert_eq(_rear_intent().move_position, CustomerFlowQueries.counter().waiting_position())


func test_watching_the_service_window_prevents_a_later_same_visit_detour() -> void:
	await _rear_fixture()
	_rear_camera.rotation.y = PI
	_rear_step()
	assert_eq(_rear_visit.stalking_visit_count, 1)
	assert_eq(_rear_person.stalking_sequence, 0)
	_rear_camera.rotation.y = 0.0
	_sense(0.1)
	_rear_step(0.1)
	assert_eq(_rear_person.stalking_sequence, 0)
	assert_null(CustomerStalkingQueries.binding(_rear_body))
	assert_eq(_rear_intent().move_position, CustomerFlowQueries.counter().waiting_position())


func test_publication_rejects_a_replaced_role_and_removes_only_its_abandoned_binding() -> void:
	await _rear_fixture()
	var replacement: C_CustomerAgent = C_CustomerAgent.new()
	replacement.visit_id = _rear_agent.visit_id
	replacement.phase = C_CustomerAgent.Phase.APPROACHING
	var observer: DuringRearBinding = DuringRearBinding.new()
	observer.on_change = func() -> void:
		_rear_body.remove_component(C_CustomerAgent)
		_rear_body.add_component(replacement)
	_world.add_observer(observer)
	_rear_step()
	_world.remove_observer(observer)
	assert_same(_rear_body.get_component(C_CustomerAgent), replacement)
	assert_eq(_rear_person.stalking_sequence, 1)
	assert_eq(_rear_visit.stalking_visit_count, 1)
	assert_null(CustomerStalkingQueries.binding(_rear_body))
	assert_eq(_rear_state.service_approach_task_id, 0)


func test_role_release_rechecks_replacement_after_rear_binding_callbacks() -> void:
	await _rear_fixture()
	_rear_step()
	var replacement: C_CustomerAgent = C_CustomerAgent.new()
	replacement.visit_id = _rear_agent.visit_id
	replacement.phase = C_CustomerAgent.Phase.APPROACHING
	var observer: DuringRearBinding = DuringRearBinding.new()
	observer.added = false
	observer.on_change = func() -> void:
		_rear_body.remove_component(C_CustomerAgent)
		_rear_body.add_component(replacement)
		var decision: C_NpcDecision = _rear_body.get_component(C_NpcDecision) as C_NpcDecision
		decision.active_task_id = 777
		NpcIntentService.move_to(_rear_body, Vector3(8, 0, 8), 0.2)
	_world.add_observer(observer)
	NpcServiceRole.release(_rear_body, _rear_visit.visit_id)
	_world.remove_observer(observer)
	assert_same(_rear_body.get_component(C_CustomerAgent), replacement)
	assert_true(_rear_intent().movement_active)
	assert_eq(_rear_intent().move_position, Vector3(8, 0, 8))
	assert_eq(_rear_body.get_relationships(Relationship.new(
			R_NpcServiceAt.new(),
			CustomerFlowQueries.counter(),
		)).size(), 1)
	assert_null(CustomerStalkingQueries.binding(_rear_body))


func test_rear_strategy_does_not_bypass_a_previous_reserved_recipient() -> void:
	await _rear_fixture(true, false)
	var first_person: NpcRecord = _district.people[0]
	var first_body: E_DistrictNpc = NpcPopulationQueries.body_for(first_person.npc_id)
	var first: CustomerVisit = _case(first_person, "ahead-of-creepy")
	NpcServiceRole.begin(first_body, first_person, first, 1)
	first.queue_order = 0
	NpcServiceRole.claim_counter(first_body)
	_rear_step()
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.QUEUED)
	assert_eq(_rear_agent.stalking_sequence, 0)
	assert_eq(_rear_person.stalking_sequence, 0)
	assert_null(CustomerStalkingQueries.binding(_rear_body))
	assert_false(NpcServiceRole.can_approach(_rear_body))


func test_skipped_service_choice_is_not_rerolled_on_later_ticks() -> void:
	await _rear_fixture()
	_rear_rule.opportunity_probability = 0.0
	_rear_step()
	assert_eq(_rear_visit.stalking_visit_count, 1)
	assert_eq(_rear_person.stalking_sequence, 1)
	assert_eq(_rear_agent.stalking_sequence, 0)
	_rear_rule.opportunity_probability = 1.0
	_sense(_rear_rule.retry_seconds + 0.1)
	_rear_step()
	assert_eq(_rear_person.stalking_sequence, 1)
	assert_eq(_rear_intent().move_position, CustomerFlowQueries.counter().waiting_position())


func test_native_speed_policy_scales_only_the_owned_rear_motion() -> void:
	await _rear_fixture()
	_rear_step()
	var motion: C_Motion = _rear_body.get_component(C_Motion) as C_Motion
	var maximum: float = motion.max_speed
	var decision: C_NpcDecision = _rear_body.get_component(C_NpcDecision) as C_NpcDecision
	assert_ne(_rear_state.service_approach_task_id, 0)
	assert_eq(decision.active_task_id, _rear_state.service_approach_task_id)
	assert_eq(decision.intent_owner, C_NpcDecision.Owner.SERVICE)
	assert_false(NpcGazeQueries.frozen(_rear_body))
	assert_false(_rear_state.observed)
	assert_true(_rear_body.has_component(C_Controller))
	var execution: S_NpcIntent = S_NpcIntent.new()
	execution.group = "rear-motion"
	_world.add_system(execution)
	_world.process(0.001, execution.group)
	assert_almost_eq(motion.control_speed_multiplier, _rear_rule.approach_speed_multiplier, 0.001)
	assert_eq(motion.max_speed, maximum)
	CustomerStalkingBindings.release(_rear_body)
	_rear_step()
	_world.process(0.001, execution.group)
	assert_eq(motion.control_speed_multiplier, 1.0)
	assert_eq(motion.max_speed, maximum)


func test_native_service_choice_keeps_reservation_phase_clock_and_fixed_destination() -> void:
	await _rear_fixture()
	_rear_step(0.7)
	assert_gt(_rear_agent.stalking_sequence, 0)
	assert_eq(_rear_visit.stalking_visit_count, 1)
	assert_eq(_rear_visit.visit_count, 1)
	assert_almost_eq(_rear_agent.elapsed, 0.7, 0.001)
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.APPROACHING)
	assert_not_null(CustomerStalkingQueries.binding(_rear_body))
	assert_eq(_rear_body.get_relationships(Relationship.new(
			R_NpcServiceAt.new(),
			CustomerFlowQueries.counter(),
		)).size(), 1)
	var destination: Vector3 = _rear_agent.stalking_destination
	var sequence: int = _rear_person.stalking_sequence
	_rear_player.global_position.x += 0.3
	_rear_step(0.2)
	assert_eq(_rear_agent.stalking_destination, destination)
	assert_eq(_rear_person.stalking_sequence, sequence)
	assert_eq(_rear_intent().move_position, destination)
	assert_almost_eq(_rear_agent.elapsed, 0.9, 0.001)


func test_rear_budget_expiry_falls_back_without_reset_or_retry() -> void:
	await _rear_fixture()
	_rear_step(0.4)
	var sequence: int = _rear_person.stalking_sequence
	_sense(_rear_rule.service_seconds + 0.1)
	_rear_step(0.8)
	assert_eq(_rear_agent.stalking_sequence, 0)
	assert_null(CustomerStalkingQueries.binding(_rear_body))
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.APPROACHING)
	assert_almost_eq(_rear_agent.elapsed, 1.2, 0.001)
	assert_eq(_rear_intent().move_position, CustomerFlowQueries.counter().waiting_position())
	_rear_step()
	assert_eq(_rear_person.stalking_sequence, sequence)
	assert_eq(_rear_visit.visit_count, 1)


func test_route_watchdog_abandons_only_the_rear_detour() -> void:
	await _rear_fixture()
	_district.definition.route_timeout = 1.0
	_rear_step(0.4)
	var sequence: int = _rear_person.stalking_sequence
	var eligible_tick: int = _rear_person.stalking_next_eligible_tick
	var reservation: Relationship = _rear_body.get_relationships(
		Relationship.new(R_NpcServiceAt.new(), CustomerFlowQueries.counter())
	)[0]
	var route: C_NpcRoute = _rear_body.get_component(C_NpcRoute) as C_NpcRoute
	NpcAiFixture.route(_rear_body, _rear_person, 0.1)
	NpcAiFixture.plan_routes(_district)
	assert_true(route.reachable, "A physically stalled rear route still has a native path")
	assert_false(_rear_intent().navigation_blocked)
	NpcAiFixture.route(_rear_body, _rear_person, 1.1)
	assert_true(_rear_body.has_component(C_CustomerAgent), "The watchdog must retain the visit")
	if not _rear_body.has_component(C_CustomerAgent):
		return
	assert_same(CustomerFlowQueries.visit_for(_rear_body), _rear_visit)
	assert_false(_rear_visit.finished)
	assert_eq(_rear_visit.deferred_day, 0)
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.APPROACHING)
	assert_almost_eq(_rear_agent.elapsed, 0.4, 0.001)
	assert_eq(_rear_visit.visit_count, 1)
	assert_eq(_rear_visit.stalking_visit_count, 1)
	assert_eq(_rear_person.stalking_sequence, sequence)
	assert_eq(_rear_person.stalking_next_eligible_tick, eligible_tick)
	assert_true(_rear_body.relationships.has(reservation))
	assert_null(CustomerStalkingQueries.binding(_rear_body))
	assert_eq(_rear_agent.stalking_sequence, 0)
	assert_eq(_rear_state.service_approach_task_id, 0)
	_rear_step()
	assert_eq(_rear_intent().move_position, CustomerFlowQueries.counter().waiting_position())
	assert_eq(_rear_person.stalking_sequence, sequence)


func test_route_watchdog_still_defers_a_blocked_ordinary_counter_approach() -> void:
	await _rear_fixture()
	_district.definition.route_timeout = 1.0
	_rear_rule.opportunity_probability = 0.0
	_rear_step(0.4)
	assert_eq(_rear_agent.stalking_sequence, 0)
	assert_eq(_rear_intent().move_position, CustomerFlowQueries.counter().waiting_position())
	var route: C_NpcRoute = _rear_body.get_component(C_NpcRoute) as C_NpcRoute
	NpcAiFixture.route(_rear_body, _rear_person, 0.1)
	NpcAiFixture.plan_routes(_district)
	assert_true(route.reachable)
	NpcAiFixture.route(_rear_body, _rear_person, 1.1)
	assert_false(_rear_body.has_component(C_CustomerAgent))
	assert_eq(_rear_visit.deferred_day, 1)
	assert_eq(_rear_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_true(_rear_visit.finished)
	assert_eq(_rear_body.get_relationships(Relationship.new(
			R_NpcServiceAt.new(),
			CustomerFlowQueries.counter(),
		)).size(), 0)


func test_distant_camera_detection_aborts_detour_without_success_memory() -> void:
	await _rear_fixture()
	_rear_step()
	_rear_camera.rotation.y = PI
	_sense(0.1)
	_rear_step()
	assert_eq(_rear_agent.stalking_sequence, 0)
	assert_eq(_rear_person.stalking_notice_tick, -1)
	assert_eq(_rear_person.memories.size(), 0)
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.APPROACHING)
	assert_eq(_rear_intent().move_position, CustomerFlowQueries.counter().waiting_position())


func test_missing_navigation_consumes_one_choice_and_uses_ordinary_counter() -> void:
	await _rear_fixture(false)
	_rear_body.navigation_agent.set_navigation_map(RID())
	_rear_step()
	assert_eq(_rear_visit.stalking_visit_count, 1)
	assert_eq(_rear_person.stalking_sequence, 1)
	assert_eq(_rear_agent.stalking_sequence, 0)
	_rear_step()
	assert_eq(_rear_person.stalking_sequence, 1)
	assert_eq(_rear_intent().move_position, CustomerFlowQueries.counter().waiting_position())


func test_player_leaving_counter_zone_aborts_without_changing_visit() -> void:
	await _rear_fixture()
	_rear_step()
	_rear_player.global_position = Vector3(10, 0, 0)
	_sense(0.1)
	_rear_step()
	assert_eq(_rear_agent.stalking_sequence, 0)
	assert_null(CustomerStalkingQueries.binding(_rear_body))
	assert_false(_rear_visit.finished)
	assert_eq(_rear_visit.visit_count, 1)
	assert_eq(_rear_intent().move_position, CustomerFlowQueries.counter().waiting_position())


func test_cancel_preserves_replacement_movement_and_durable_choice() -> void:
	await _rear_fixture()
	_rear_step()
	var deadline: int = _rear_person.stalking_next_eligible_tick
	var decision: C_NpcDecision = _rear_body.get_component(C_NpcDecision) as C_NpcDecision
	decision.intent_owner = C_NpcDecision.Owner.COMBAT
	decision.active_task_id = 777
	NpcIntentArbiter.move_to(_rear_body, Vector3(9, 0, 9), 0.2, C_NpcDecision.Owner.COMBAT)
	CustomerStalkingBindings.release(_rear_body)
	assert_eq(decision.active_task_id, 777)
	assert_true(_rear_intent().movement_active)
	assert_eq(_rear_intent().move_position, Vector3(9, 0, 9))
	assert_eq(_rear_person.stalking_next_eligible_tick, deadline)
	assert_eq(_rear_visit.stalking_visit_count, 1)
	assert_null(CustomerStalkingQueries.binding(_rear_body))
#endregion


#region Actual arrival and observed order
func test_detection_at_reached_point_before_next_bt_step_commits_service_arrival() -> void:
	await _rear_fixture()
	_rear_step()
	_rear_body.place_at(_rear_agent.stalking_destination)
	var contact: Vector3 = _rear_body.global_position
	_look_at_rear_contact()
	_sense(0.1)
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	assert_true(_rear_agent.order_announced)
	assert_eq(_rear_agent.service_contact_position, contact)
	assert_eq(_rear_person.memories.size(), 1)
	assert_eq(_rear_visit.visit_count, 1)
	_rear_step()
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.WAITING_FOR_PACKAGE)
	assert_false(_rear_intent().movement_active)
	assert_eq(_rear_body.global_position, contact)


func test_hidden_rear_arrival_waits_for_real_detection_then_announces_own_number_once() -> void:
	await _rear_fixture()
	_reach_rear()
	var contact: Vector3 = _rear_body.global_position
	CustomerFlowFixture.greet(_rear_body)
	CustomerFlowService.greet(_rear_body)
	assert_false(_rear_agent.order_announced)
	assert_true(_rear_agent.rear_contact_pending)
	assert_false((_rear_body.get_node("Message") as Label3D).text.contains("003"))
	_rear_step(0.6)
	_look_at_rear_contact()
	_sense(0.1)
	assert_true(_rear_agent.order_announced)
	assert_false(_rear_agent.rear_contact_pending)
	assert_eq(_rear_agent.stalking_sequence, 0)
	assert_eq(_rear_body.global_position, contact)
	assert_string_contains((_rear_body.get_node("Message") as Label3D).text, "003")
	assert_almost_eq(_rear_agent.elapsed, 0.6, 0.001)
	assert_eq(_rear_person.memories.size(), 1)
	assert_gte(
		_rear_person.stalking_next_eligible_tick - _rear_person.stalking_notice_tick,
		NpcStalkingRules.MIN_SUCCESS_COOLDOWN_TICKS,
	)
	_sense(0.2)
	assert_eq(_rear_person.memories.size(), 1)
	assert_true(get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP).is_empty())


func test_default_manual_visit_announces_number_only_after_rear_detection() -> void:
	await _rear_fixture()
	_rear_visit.definition = load(
		"res://content/domains/customers/definitions/def_customer_visit_default.tres"
	) as DEF_Customer
	assert_false(CustomerPresentation.uses_quick_visit(_rear_visit))
	CustomerGreetingService.announce_order(_rear_body, _rear_visit)
	assert_false(_rear_agent.order_announced, "Ordinary manual arrival still requires dialogue")
	_reach_rear()
	CustomerGreetingService.announce_order(_rear_body, _rear_visit)
	assert_false(_rear_agent.order_announced, "The hidden contact must not disclose the number")
	_look_at_rear_contact()
	_sense(0.1)
	assert_true(_rear_agent.order_announced)
	assert_false(_rear_agent.rear_contact_pending)
	assert_string_contains((_rear_body.get_node("Message") as Label3D).text, "003")
	var message: String = (_rear_body.get_node("Message") as Label3D).text
	_sense(0.2)
	CustomerGreetingService.announce_order(_rear_body, _rear_visit)
	assert_eq((_rear_body.get_node("Message") as Label3D).text, message)
	assert_eq(_rear_person.memories.size(), 1)
	assert_true(get_tree().get_nodes_in_group(NpcDialogueService.ACTIVE_GROUP).is_empty())


func test_rear_arrival_does_not_invent_an_unregistered_number() -> void:
	await _rear_fixture()
	(PackageQueries.ledger().records[0] as PackageRegistrationRecord).number = 0
	_reach_rear()
	_look_at_rear_contact()
	_sense(0.1)
	assert_false(_rear_agent.rear_contact_pending)
	assert_false(_rear_agent.order_announced)
	assert_false((_rear_body.get_node("Message") as Label3D).text.contains("003"))


func test_rear_contact_remains_the_inspection_return_position() -> void:
	await _rear_fixture()
	_reach_rear()
	var contact: Vector3 = _rear_body.global_position
	CustomerInspectionService.return_to_service(_rear_body, _rear_visit)
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH)
	assert_eq(CustomerInspectionService.destination(_rear_body), contact)
	assert_eq(_rear_intent().move_position, contact)
	_sense(0.1)
	assert_null(CustomerStalkingQueries.binding(_rear_body))
	assert_eq(_rear_agent.service_contact_position, contact)


func test_unseen_rear_contact_expires_through_ordinary_patience() -> void:
	await _rear_fixture()
	_reach_rear()
	_rear_step(_rear_visit.definition.patience_seconds + 0.1)
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.LEAVING)
	assert_eq(_rear_visit.actual, CustomerVisit.Actual.NOT_RESOLVED)
	assert_false(_rear_agent.order_announced)
	_sense(0.1)
	assert_null(CustomerStalkingQueries.binding(_rear_body))


func test_actual_handoff_at_rear_contact_does_not_return_the_receiver_to_counter() -> void:
	await _rear_fixture()
	_reach_rear()
	var contact: Vector3 = _rear_body.global_position
	_rear_player.global_position = contact + Vector3(0, 0, -0.8)
	_look_at_rear_contact()
	_sense(0.1)
	_world.add_observer(O_GrabLifecycle.new())
	var parcel: E_Package = (
		load("res://content/domains/packages/entities/package_a.tscn") as PackedScene
	).instantiate() as E_Package
	parcel.gravity_scale = 0.0
	EntityCompositionFixture.register(_world, parcel)
	(parcel.get_component(C_Package) as C_Package).package_id = _rear_visit.package_id
	(parcel.get_component(C_PackageState) as C_PackageState).registration = (
		C_PackageState.Registration.REGISTERED
	)
	CustomerParcelAssignment.bind_parcel(_rear_body, _rear_visit)
	parcel.add_relationship(Relationship.new(R_HeldBy.new(), _rear_player))
	parcel.global_position = _rear_player.hold_anchor.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var wallet: C_Wallet = WalletService.current()
	var operations_before: int = wallet.operations.size()
	assert_true(CustomerFlowService.try_automatic_handoff(_rear_body, _rear_visit))
	assert_eq(_rear_visit.actual, CustomerVisit.Actual.DELIVERED)
	assert_true(CustomerOutcomeService.declare(_rear_visit, CustomerVisit.Declaration.TAKEN))
	assert_true(_rear_visit.settlement_committed)
	assert_gt(_rear_visit.money_delta, 0)
	assert_eq(wallet.operations.size(), operations_before + 1)
	assert_eq(_rear_agent.phase, C_CustomerAgent.Phase.RECEIVING)
	assert_eq(_rear_body.global_position, contact)
	assert_eq(_rear_visit.visit_count, 1)
	assert_false(CustomerFlowService.try_automatic_handoff(_rear_body, _rear_visit))
	assert_eq(wallet.operations.size(), operations_before + 1)
	_sense(0.1)
	assert_null(CustomerStalkingQueries.binding(_rear_body))
#endregion
