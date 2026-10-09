extends "res://tests/gut/test_district_population.gd"
## Verifies the single retained-body participation owner and actual native processing eligibility.


#region Participation ownership
## Confirmed death during disable must supersede the requested nonterminal dormant placement.
func test_death_inside_native_disable_commits_dead_placement() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var stable_body: int = body.get_instance_id()
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	var callback: Callable = func(candidate: Entity) -> void:
		if candidate == body:
			body.add_component(C_Death.new())
	_world.entity_disabled.connect(callback)
	var committed: bool = DistrictPopulationService.set_placement(
		person,
		body,
		NpcRecord.Placement.OUTSIDE,
	)
	_world.entity_disabled.disconnect(callback)
	assert_false(committed, "Confirmed death supersedes ordinary departure")
	assert_gt(person.death_day, 0)
	assert_eq(person.placement, NpcRecord.Placement.DEAD)
	assert_true(person.phase_complete)
	assert_eq(body.get_instance_id(), stable_body)
	assert_false(body.enabled)
	assert_true(body.freeze)
	assert_eq(body.collision_layer, 0)
	assert_false(body.animation_player.can_process())
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	var generation: int = decision.participation_generation
	DistrictPopulationService.mark_dead(person, body, DayPhaseQueries.current().day_index)
	assert_eq(decision.participation_generation, generation)


## Night's uncommitted death history keeps its original morning reconciliation boundary.
func test_disable_callback_preserves_night_death_history_policy() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	cycle.phase = C_DayCycle.Phase.NIGHT
	var callback: Callable = func(candidate: Entity) -> void:
		if candidate == body:
			body.add_component(C_Death.new())
	_world.entity_disabled.connect(callback)
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE))
	_world.entity_disabled.disconnect(callback)
	assert_eq(person.death_day, 0)
	assert_eq(person.placement, NpcRecord.Placement.OUTSIDE)
	cycle.phase = C_DayCycle.Phase.MORNING
	cycle.day_index = 2
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	_world.emit_event(DayPhaseChanged.EVENT, session, DayPhaseChanged.from_cycle(cycle))
	assert_eq(person.death_day, 2)
	assert_eq(person.placement, NpcRecord.Placement.DEAD)


## Opposite transitions inside GECS native signals are rejected until native signal wiring finishes.
func test_nested_opposite_transition_is_rejected_without_corrupting_dormancy() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
	var reentrant_results: Array[bool] = []
	var callback: Callable = func(candidate: Entity) -> void:
		if candidate == body:
			reentrant_results.append(
				DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET)
			)
	_world.entity_disabled.connect(callback)
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE))
	_world.entity_disabled.disconnect(callback)
	assert_eq(reentrant_results, [false])
	assert_eq(person.placement, NpcRecord.Placement.OUTSIDE)
	assert_false(body.enabled)
	assert_false(body.is_processing())
	assert_false(body.animation_player.can_process())
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET))
	assert_true(body.is_processing())
	assert_true(body.animation_player.can_process())


## Repeated transitions preserve identity and invalidate captured work only once per change.
func test_retained_body_transition_is_idempotent_and_preserves_identity() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	var body_identity: int = body.get_instance_id()
	var entity_identity: String = body.id
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET))
	decision.scheduled_delta = 0.2
	var active_generation: int = decision.lifecycle_generation
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE))
	var dormant_generation: int = decision.lifecycle_generation
	assert_eq(dormant_generation, active_generation + 1)
	assert_eq(decision.scheduled_delta, 0.0)
	assert_false(body.enabled)
	assert_true(body.freeze)
	assert_false(body.visible)
	assert_eq(body.collision_layer, 0)
	assert_eq(body.collision_mask, 0)
	assert_eq(body.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(body.navigation_agent.avoidance_enabled)
	assert_false((body.get_node("Brain") as BTPlayer).active)
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.OUTSIDE))
	assert_eq(decision.lifecycle_generation, dormant_generation)
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET))
	assert_eq(body.get_instance_id(), body_identity)
	assert_eq(body.id, entity_identity)
	assert_true(body.enabled)
	assert_false(body.freeze)
	assert_true(body.visible)
	assert_eq(body.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_true(body.navigation_agent.avoidance_enabled)
	assert_true((body.get_node("Brain") as BTPlayer).active)
	var reactivated_generation: int = decision.lifecycle_generation
	assert_true(DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.STREET))
	assert_eq(decision.lifecycle_generation, reactivated_generation)


## Native reconstruction reconciles participation through the same placement operation.
func test_restore_reconciles_existing_dormant_body_and_children() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
	DistrictPopulationService.set_placement(person, body, NpcRecord.Placement.HOME)
	DistrictPopulationService.restore_participation()
	assert_same(NpcPopulationQueries.body_for(person.npc_id), body)
	assert_false(body.enabled)
	assert_true(body.freeze)
	assert_false(body.animation_player.can_process())
	assert_false((body.get_node("Brain") as BTPlayer).active)
	var state: Dictionary[String, Variant] = NpcDecisionDiagnostics.actor_state(body)
	assert_eq(state["participation"], "DORMANT")
	assert_eq(state["participation_reason"], "snapshot_restored")


## Both the root and inherited animation processing stop without freeing any physical actor.
func test_processing_accounting_retains_all_bodies_without_dormant_animation_work() -> void:
	var active_actors: int = 0
	var processing_roots: int = 0
	var processing_animations: int = 0
	for person: NpcRecord in _district.people:
		var body: E_DistrictNpc = NpcPopulationQueries.body_for(person.npc_id)
		assert_not_null(body)
		if body.enabled:
			active_actors += 1
		if body.is_processing():
			processing_roots += 1
		if body.animation_player != null and body.animation_player.active \
				and body.animation_player.can_process():
			processing_animations += 1
		if not body.enabled:
			assert_false(body.animation_player.can_process())
	assert_eq(processing_roots, active_actors)
	assert_eq(processing_animations, active_actors)
	assert_eq(_world.query.with_all([C_NpcIdentity]).execute().size(), _district.people.size())
	print(
		"NPC participation processing: retained=%d active=%d roots=%d animations=%d"
		% [_district.people.size(), active_actors, processing_roots, processing_animations]
	)
#endregion
