extends GutTest
## Native customer lifetime and schedule pacing; no navigation or rendered frames required.

var _world: World
var _flow: C_CustomerFlow
var _cycle: C_DayCycle


func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	var session: Entity = Entity.new()
	session.component_resources = [C_CustomerFlow.new(), C_DayCycle.new()]
	_world.add_entity(session)
	_flow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle = session.get_component(C_DayCycle) as C_DayCycle
	_cycle.phase = C_DayCycle.Phase.DAY
	_flow.schedule = DEF_CustomerSchedule.new()
	_flow.schedule.supply = null
	_flow.schedule.customer_scene = load("res://content/entities/customers/customer.tscn") as PackedScene
	var counter_scene: PackedScene = load("res://content/entities/stations/delivery_counter.tscn") as PackedScene
	var counter: E_DeliveryCounter = counter_scene.instantiate() as E_DeliveryCounter
	_world.add_entity(counter)


func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _visit(id: StringName) -> CustomerVisit:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = id
	visit.definition = DEF_Customer.new()
	visit.definition.max_followup_visits = 0
	visit.requires_registered_package = false
	_flow.visits.append(visit)
	return visit


func _leaving_customer(visit: CustomerVisit) -> E_Customer:
	var body: RigidBody3D = RigidBody3D.new()
	body.freeze = true
	body.set_script(load("res://content/entities/customers/e_customer.gd"))
	var customer: E_Customer = body as Node as E_Customer
	customer.component_resources = [C_CustomerAgent.new(), C_NpcIntent.new()]
	_world.add_entity(customer)
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	agent.visit_id = visit.visit_id
	agent.phase = C_CustomerAgent.Phase.LEAVING
	visit.started = true
	visit.visit_count = 1
	return customer


func test_legacy_short_departure_cannot_remove_customer_before_three_minutes() -> void:
	var visit: CustomerVisit = _visit(&"blocked-exit")
	visit.definition.leaving_seconds = 2.0
	var customer: E_Customer = _leaving_customer(visit)
	CustomerFlowService.tick(_flow, _cycle, 180.0)
	assert_eq(CustomerFlowService.customer_for(visit.visit_id), customer)
	assert_false(visit.finished)
	assert_eq(_flow.arrival_cooldown_seconds, 0.0)
	CustomerFlowService.tick(_flow, _cycle, 1.0)
	assert_null(CustomerFlowService.customer_for(visit.visit_id))
	assert_true(visit.finished)
	assert_eq(_flow.arrival_cooldown_seconds, 30.0)


func test_arriving_at_exit_finishes_immediately_and_starts_gap_once() -> void:
	var visit: CustomerVisit = _visit(&"exit-arrived")
	var customer: E_Customer = _leaving_customer(visit)
	(customer.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	CustomerFlowService.tick(_flow, _cycle, 0.1)
	assert_null(CustomerFlowService.customer_for(visit.visit_id))
	assert_true(visit.finished)
	_flow.arrival_cooldown_seconds = 7.0
	CustomerFlowService.finish(visit, _cycle.day_index)
	assert_eq(_flow.arrival_cooldown_seconds, 7.0, "Duplicate completion cannot restart the gap")


func test_next_eligible_customer_waits_for_configured_gap_after_previous_departure() -> void:
	_flow.schedule.arrival_interval_seconds = 45.0
	var previous: CustomerVisit = _visit(&"previous")
	var customer: E_Customer = _leaving_customer(previous)
	var next: CustomerVisit = _visit(&"next")
	assert_false(CustomerFlowService.spawn_next_due(_flow, _cycle), "Leaving NPC still occupies the visit slot")
	(customer.get_component(C_NpcIntent) as C_NpcIntent).arrived = true
	CustomerFlowService.tick(_flow, _cycle, 0.1)
	assert_false(next.started)
	CustomerFlowService.tick(_flow, _cycle, 44.0)
	assert_false(next.started)
	assert_string_contains(CustomerDebugPresentation.summary(), "Пауза до следующего: 1 с")
	CustomerFlowService.tick(_flow, _cycle, 1.0)
	assert_true(next.started)
	assert_not_null(CustomerFlowService.customer_for(next.visit_id))
	assert_eq(next.visit_count, 1)


func test_first_customer_and_morning_are_not_delayed_by_previous_day_gap() -> void:
	var first: CustomerVisit = _visit(&"first")
	assert_true(CustomerFlowService.spawn_next_due(_flow, _cycle))
	assert_not_null(CustomerFlowService.customer_for(first.visit_id))
	_flow.arrival_cooldown_seconds = 30.0
	_cycle.phase = C_DayCycle.Phase.MORNING
	CustomerFlowService.tick(_flow, _cycle, 0.0)
	assert_eq(_flow.arrival_cooldown_seconds, 0.0)


func test_single_live_customer_blocks_queue_and_debug_even_after_accounting_finished() -> void:
	var previous: CustomerVisit = _visit(&"still-physically-present")
	var customer: E_Customer = _leaving_customer(previous)
	var queued: CustomerVisit = _visit(&"queued")
	previous.finished = true
	var agent: C_CustomerAgent = customer.get_component(C_CustomerAgent) as C_CustomerAgent
	for phase: C_CustomerAgent.Phase in [C_CustomerAgent.Phase.RECEIVING, C_CustomerAgent.Phase.GOING_TO_BOOTH, C_CustomerAgent.Phase.INSPECTING, C_CustomerAgent.Phase.RETURNING_FROM_BOOTH, C_CustomerAgent.Phase.AGGRESSIVE, C_CustomerAgent.Phase.LEAVING]:
		agent.phase = phase
		assert_false(CustomerFlowService.spawn_next_due(_flow, _cycle))
		assert_false(DebugWorldService.customer_next().success)
		assert_false(queued.started)
		assert_eq(_world.query.with_all([C_CustomerAgent]).execute().size(), 1)
	_world.remove_entity(customer)
	assert_true(CustomerFlowService.spawn_next_due(_flow, _cycle))
	assert_true(queued.started)
	assert_eq(_world.query.with_all([C_CustomerAgent]).execute().size(), 1)


func test_unspawned_visit_completion_does_not_add_artificial_delay() -> void:
	var missed: CustomerVisit = _visit(&"unspawned")
	CustomerFlowService.finish(missed, _cycle.day_index)
	assert_true(missed.finished)
	assert_eq(_flow.arrival_cooldown_seconds, 0.0)
	var next: CustomerVisit = _visit(&"first-real")
	assert_true(CustomerFlowService.spawn_next_due(_flow, _cycle))
	assert_true(next.started)
	assert_eq(missed.visit_count, 0, "Already finished unspawned visits cannot spawn again")


func test_authored_gaze_has_twelve_seconds_and_light_entrance_is_not_scaled_twice() -> void:
	var gaze: DEF_Challenge = load("res://content/definitions/gameplay/challenges/def_challenge_dont_look.tres") as DEF_Challenge
	var state: C_Challenge = C_Challenge.new()
	state.definition = gaze
	var subject: Entity = Entity.new()
	subject.component_resources = [state]
	_world.add_entity(subject)
	state = subject.get_component(C_Challenge) as C_Challenge
	var actor: Entity = Entity.new()
	_world.add_entity(actor)
	assert_true(ChallengeService.arm(subject, actor))
	assert_true(ChallengeService.activate(subject))
	state.condition_result = ChallengeResult.Type.FAILURE
	ChallengeService.tick(subject, state, 11.9)
	assert_null(state.pending_result)
	ChallengeService.tick(subject, state, 0.1)
	assert_not_null(state.pending_result)
	assert_eq(state.pending_result.result, ChallengeResult.Type.FAILURE)
	var entrance: DEF_Challenge = load("res://content/definitions/gameplay/challenges/def_challenge_light_entrance.tres") as DEF_Challenge
	assert_eq(entrance.timeout_seconds, 80.0)
