extends "res://tests/gut/test_district_population.gd"
## Missing authored arrival targets reject real phase and customer activation requests.


#region Target lifetime
## Deleted home and portal definitions cannot redirect an arrival to an unrelated origin.
func test_missing_home_or_portal_rejects_arrival_and_visit_until_explicit_retry() -> void:
	_district.definition = _district.definition.duplicate(true) as DEF_District
	for index: int in [0, 8]:
		var person: NpcRecord = _district.people[index]
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		var placement: NpcRecord.Placement = NpcRecord.Placement.HOME if index == 0 \
				else NpcRecord.Placement.OUTSIDE
		DistrictPopulationService.set_placement(person, body, placement)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var old_position: Vector3 = body.global_position
		var target_id: StringName = person.home_id if index == 0 else person.portal_id
		var target: DEF_DistrictPlace = _district.definition.place_for(target_id)
		_district.definition.places.erase(target)
		var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
		var generation: int = decision.participation_generation
		var phase: C_DayCycle.Phase = C_DayCycle.Phase.MORNING if index == 0 \
				else C_DayCycle.Phase.DAY
		assert_true(DistrictPopulationService.request_phase(body, 1, phase).succeeded)
		assert_false(body.enabled)
		assert_eq(body.global_position, old_position)
		assert_eq(decision.participation_generation, generation)
		assert_false(person.phase_complete)
		var goal: StringName = person.goal_id
		var visit: CustomerVisit = CustomerVisit.new()
		visit.visit_id = StringName("test/missing_target/%d" % index)
		visit.customer_id = person.npc_id
		assert_false(NpcServiceRole.begin(body, person, visit, 1))
		assert_false(visit.started)
		assert_eq(visit.visit_count, 0)
		assert_false(body.has_component(C_CustomerAgent))
		_district.definition.places.append(target)
		assert_true(DistrictPopulationService.request_phase(body, 1, phase).succeeded)
		assert_true(body.enabled)
		assert_eq(person.goal_id, goal)
		assert_same(NpcPopulationQueries.body_for(person.npc_id), body)


## A declared live anchor cannot silently fall back to the authored coordinate after loss.
func test_missing_declared_anchor_rejects_service_arrival() -> void:
	_district.definition = _district.definition.duplicate(true) as DEF_District
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.HOME)
	var target: DEF_DistrictPlace = _district.definition.place_for(person.home_id)
	target.anchor_path = NodePath("RemovedArrivalAnchor")
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.participation_generation
	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = &"test/missing_anchor"
	visit.customer_id = person.npc_id
	assert_false(NpcServiceRole.begin(body, person, visit, 1))
	assert_false(body.enabled)
	assert_false(visit.started)
	assert_eq(visit.visit_count, 0)
	assert_eq(decision.participation_generation, generation)
#endregion
