extends "res://tests/gut/test_district_population.gd"
## Проверяет временное обслуживание постоянных личностей и исключительное владение стойкой.

#region Окружение обслуживания
## Дополняет население обычным журналом заказов и реальной стойкой обслуживания.
func before_each() -> void:
	super.before_each()
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_CustomerFlow.new())
	var counter: E_DeliveryCounter = (load("res://content/entities/stations/delivery_counter.tscn") as PackedScene).instantiate() as E_DeliveryCounter
	_world.add_entity(counter)

func _case(person: NpcRecord, suffix: String) -> CustomerVisit:
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = StringName("district/case/" + suffix)
	visit.customer_id = person.npc_id
	visit.package_id = "test/" + suffix
	visit.definition = (load("res://content/definitions/gameplay/customers/def_customer_schedule_default.tres") as DEF_CustomerSchedule).events[0].customer
	visit.requires_registered_package = false
	CustomerFlowService.current().visits.append(visit)
	return visit

## Исполняет настоящий ресурс дерева; тестовые тела сохраняют BTPlayer между тактами.
func _run_tree(body: E_DistrictNpc, tree_path: String, delta: float) -> bool:
	var runner: BTPlayer = body.get_node("Brain") as BTPlayer
	if runner.behavior_tree.resource_path != tree_path:
		runner.behavior_tree = load(tree_path) as BehaviorTree
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	decision.intent_owner = C_NpcDecision.Owner.NONE
	NpcServiceRole.advance(body, delta)
	return NpcBrainService.update_tree(body, delta)
#endregion

#region Постоянство и очередь обслуживания
## Отладочная подпись определена для всех фаз обслуживания, включая очередь.
func test_debug_projection_covers_every_service_phase() -> void:
	assert_eq(CustomerDebugPresentation.PHASE_NAMES.size(), C_CustomerAgent.Phase.size())
	assert_eq(CustomerDebugPresentation.PHASE_NAMES[C_CustomerAgent.Phase.QUEUED], "В очереди")

## Завершение разных заказов освобождает роль, сохраняя одну живую физическую личность.
func test_two_cases_use_the_same_living_body() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var first: CustomerVisit = _case(person, "first")
	NpcServiceRole.begin(body, person, first, 1)
	NpcServiceRole.finish_appearance(body, first)
	assert_true(first.finished)
	assert_false(body.has_component(C_CustomerAgent))
	assert_same(DistrictPopulationService.body_for(person.npc_id), body)

	var second: CustomerVisit = _case(person, "second")
	NpcServiceRole.begin(body, person, second, 2)
	assert_same(DistrictPopulationService.body_for(person.npc_id), body)
	assert_eq((body.get_component(C_CustomerAgent) as C_CustomerAgent).visit_id, second.visit_id)
	assert_ne(first.visit_id, second.visit_id)
	assert_eq(first.customer_id, second.customer_id)

## Два ожидающих получателя не могут одновременно владеть местом обслуживания.
func test_counter_reservation_is_exclusive_and_released() -> void:
	DayPhaseService.current().phase = C_DayCycle.Phase.DAY
	_district.definition.service_transfer_pause = 0.0
	var first_person: NpcRecord = _district.people[0]
	var second_person: NpcRecord = _district.people[3]
	var first_body: E_DistrictNpc = DistrictPopulationService.body_for(first_person.npc_id)
	var second_body: E_DistrictNpc = DistrictPopulationService.body_for(second_person.npc_id)
	var first: CustomerVisit = _case(first_person, "queue_first")
	var second: CustomerVisit = _case(second_person, "queue_second")
	NpcServiceRole.begin(first_body, first_person, first, 1)
	NpcServiceRole.begin(second_body, second_person, second, 1)
	NpcServiceRole.claim_counter(first_body)
	NpcServiceRole.claim_counter(second_body)
	assert_eq((first_body.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.APPROACHING)
	assert_eq((second_body.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.QUEUED)
	NpcServiceRole.finish_appearance(first_body, first)
	NpcServiceRole.claim_counter(second_body)
	assert_eq((second_body.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.APPROACHING)

## Поставки разных дней имеют разные случаи обслуживания и общий постоянный ID получателя.
func test_planned_shipments_share_lifetime_identity() -> void:
	var flow: C_CustomerFlow = CustomerFlowService.current()
	flow.schedule = load("res://content/definitions/gameplay/customers/def_customer_schedule_default.tres") as DEF_CustomerSchedule
	var definition: DEF_Package = flow.schedule.supply.packages[0]
	for day_index: int in [1, 2]:
		var identity: C_Package = C_Package.new()
		identity.definition = definition
		identity.supply_key = flow.schedule.supply.key
		identity.delivery_day = day_index
		CustomerFlowService.plan_delivered_package(identity)
	CustomerFlowFixture.plan(flow, 2, 10)
	var books: Array[CustomerVisit] = []
	for visit: CustomerVisit in flow.visits:
		if visit.package_id.ends_with(":books"):
			books.append(visit)
	assert_eq(books.size(), 2)
	assert_eq(books[0].customer_id, books[1].customer_id)
	assert_ne(books[0].visit_id, books[1].visit_id)
	assert_same(DistrictPopulationService.body_for(books[0].customer_id), DistrictPopulationService.body_for(books[1].customer_id))

## Следующий получатель готовится заранее, но стойку получает только после ухода текущего.
func test_next_recipient_starts_after_current_is_released() -> void:
	_district.definition.service_transfer_pause = 0.0
	var flow: C_CustomerFlow = CustomerFlowService.current()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.arrival_interval_seconds = 0.0
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var first: CustomerVisit = _case(_district.people[0], "sequential_first")
	var second: CustomerVisit = _case(_district.people[3], "sequential_second")
	assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	assert_true(first.started)
	assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	assert_true(second.started)
	var first_body: E_DistrictNpc = DistrictPopulationService.body_for(first.customer_id)
	var second_body: E_DistrictNpc = DistrictPopulationService.body_for(second.customer_id)
	NpcServiceRole.claim_counter(first_body)
	assert_false(NpcServiceRole.can_approach(second_body))
	NpcServiceRole.finish_appearance(first_body, first)
	assert_true(NpcServiceRole.can_approach(second_body))
	assert_ne(first.customer_id, second.customer_id)

## Смерть текущего освобождает обслуживание для другой постоянной личности.
func test_current_death_allows_another_recipient() -> void:
	var flow: C_CustomerFlow = CustomerFlowService.current()
	flow.schedule = DEF_CustomerSchedule.new()
	flow.schedule.arrival_interval_seconds = 0.0
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.DAY
	var first: CustomerVisit = _case(_district.people[0], "dead_first")
	var second: CustomerVisit = _case(_district.people[3], "live_second")
	assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	DistrictPopulationService.mark_dead(_district.people[0], DistrictPopulationService.body_for(first.customer_id), 1)
	assert_true(first.customer_dead)
	assert_true(NpcServiceRole.enqueue_next(flow, cycle))
	assert_true(second.started)

## Бесконечное утро без поставки не создаёт ожидающих визитов и ложных потерь.
func test_calendar_without_boxes_does_not_create_district_cases() -> void:
	var flow: C_CustomerFlow = CustomerFlowService.current()
	flow.schedule = DEF_CustomerSchedule.new()
	CustomerFlowFixture.plan(flow, 20, 10)
	assert_eq(flow.visits.size(), 0)
#endregion
