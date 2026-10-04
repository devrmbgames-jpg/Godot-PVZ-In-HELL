extends "res://tests/gut/test_district_population.gd"
## Persistent person service roles preserve existing cases and serialize queue ownership.

#region Service fixture
## Adds the unchanged parcel journal and a real counter to the population fixture.
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
#endregion

#region Persistent service behavior
## Ending a parcel appearance releases its role rather than deleting the person.
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

## Two queued people cannot simultaneously reserve the serving position.
func test_counter_reservation_is_exclusive_and_released() -> void:
	var first_person: NpcRecord = _district.people[0]
	var second_person: NpcRecord = _district.people[3]
	var first_body: E_DistrictNpc = DistrictPopulationService.body_for(first_person.npc_id)
	var second_body: E_DistrictNpc = DistrictPopulationService.body_for(second_person.npc_id)
	var first: CustomerVisit = _case(first_person, "queue_first")
	var second: CustomerVisit = _case(second_person, "queue_second")
	NpcServiceRole.begin(first_body, first_person, first, 1)
	NpcServiceRole.begin(second_body, second_person, second, 1)
	NpcServiceRole.step_queue(first_body, first)
	NpcServiceRole.step_queue(second_body, second)
	assert_eq((first_body.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.APPROACHING)
	assert_eq((second_body.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.QUEUED)
	NpcServiceRole.finish_appearance(first_body, first)
	NpcServiceRole.step_queue(second_body, second)
	assert_eq((second_body.get_component(C_CustomerAgent) as C_CustomerAgent).phase, C_CustomerAgent.Phase.APPROACHING)

## Daily shipments have distinct case IDs but share permanent recipient identity.
func test_planned_shipments_share_lifetime_identity() -> void:
	var flow: C_CustomerFlow = CustomerFlowService.current()
	flow.schedule = load("res://content/definitions/gameplay/customers/def_customer_schedule_default.tres") as DEF_CustomerSchedule
	CustomerFlowService.plan_day(flow, 2, 10)
	var books: Array[CustomerVisit] = []
	for visit: CustomerVisit in flow.visits:
		if visit.package_id.ends_with(":books"):
			books.append(visit)
	assert_eq(books.size(), 2)
	assert_eq(books[0].customer_id, books[1].customer_id)
	assert_ne(books[0].visit_id, books[1].visit_id)
	assert_same(DistrictPopulationService.body_for(books[0].customer_id), DistrictPopulationService.body_for(books[1].customer_id))
#endregion
