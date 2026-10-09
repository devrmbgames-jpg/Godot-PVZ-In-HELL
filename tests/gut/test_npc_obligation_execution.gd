extends "res://tests/gut/test_district_plan_acceptance.gd"
## Exercises native adapters, authoritative completion and interrupted obligation resumption.


#region Native execution acceptance
func _departure() -> E_DistrictNpc:
	var body: E_DistrictNpc = _stage(0, Vector3(-8, 0, 0))
	var person: NpcRecord = _district.people[0]
	person.profile.schedule = person.profile.schedule.duplicate() as DEF_NpcSchedule
	person.profile.schedule.day = DEF_NpcSchedule.Location.OUTSIDE
	assert_true(DistrictPopulationService.request_phase(body, 1, C_DayCycle.Phase.DAY).succeeded)
	return body


## Moving and finishing are one accepted incarnation, with success committed by the district owner.
func test_native_schedule_retains_action_until_real_arrival() -> void:
	var body: E_DistrictNpc = _departure()
	var person: NpcRecord = _district.people[0]
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	var generation: int = decision.action_generation
	assert_eq(decision.action_status, C_NpcDecision.ActionStatus.RUNNING)
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	assert_eq(decision.action_generation, generation, "Running work must not restart each tick")
	assert_false(person.phase_complete)
	body.place_at(NpcPopulationQueries.position_for(person.goal_id))
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	assert_eq(decision.action_generation, generation)
	assert_eq(decision.action_status, C_NpcDecision.ActionStatus.COMPLETED)
	assert_true(person.phase_complete)
	assert_eq(decision.action_reason, &"obligation_completed")
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)


## A native emergency cancels execution; the unchanged obligation resumes later.
func test_priority_interrupt_cancels_then_resumes_same_obligation() -> void:
	var body: E_DistrictNpc = _departure()
	var person: NpcRecord = _district.people[0]
	var obligation: StringName = person.goal_id
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	_run_tree(body, NpcBrainService.TREE_PATH, 0.2)
	var previous: int = decision.action_generation
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	awareness.fleeing = true
	_run_tree(body, NpcBrainService.TREE_PATH, 0.2)
	assert_eq(decision.intent_owner, C_NpcDecision.Owner.EMERGENCY)
	assert_eq(decision.action_status, C_NpcDecision.ActionStatus.CANCELLED)
	assert_eq(decision.action_reason, &"priority_interrupted")
	assert_false(person.phase_complete)
	assert_eq(person.goal_id, obligation)
	awareness.fleeing = false
	_run_tree(body, NpcBrainService.TREE_PATH, 0.2)
	assert_eq(decision.action_status, C_NpcDecision.ActionStatus.RUNNING)
	assert_gt(decision.action_generation, previous)
	assert_eq(person.goal_id, obligation)


## Missing authored destinations fail execution instead of completing at Vector3.ZERO.
func test_target_loss_fails_without_fabricated_completion_then_retries() -> void:
	var body: E_DistrictNpc = _departure()
	var person: NpcRecord = _district.people[0]
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	var previous: int = decision.action_generation
	_district.definition = _district.definition.duplicate() as DEF_District
	var places: Array[DEF_DistrictPlace] = _district.definition.places.duplicate()
	_district.definition.places.erase(_district.definition.place_for(person.goal_id))
	body.place_at(Vector3.ZERO)
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	assert_eq(decision.action_status, C_NpcDecision.ActionStatus.FAILED)
	assert_eq(decision.action_reason, &"target_unavailable")
	assert_false(person.phase_complete)
	assert_false((body.get_component(C_NpcIntent) as C_NpcIntent).movement_active)
	_district.definition.places = places
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	assert_eq(decision.action_status, C_NpcDecision.ActionStatus.RUNNING)
	assert_gt(decision.action_generation, previous)


## A stale queued completion cannot finish a replacement action or its authored obligation.
func test_queued_completion_rejects_cancelled_action_incarnation() -> void:
	var body: E_DistrictNpc = _departure()
	var person: NpcRecord = _district.people[0]
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	var owner: O_DistrictLifecycle = null
	for observer: Observer in _world.observers:
		if observer is O_DistrictLifecycle:
			owner = observer as O_DistrictLifecycle
	owner.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: NpcScheduleCompletionRequest = DistrictPopulationService.request_phase_completion(
		body
	)
	assert_false(request.completed)
	NpcScheduleActionService.cancel_schedule(body, &"test_cancel")
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	var replacement: int = decision.action_generation
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_false(request.succeeded)
	assert_eq(request.rejection_reason, &"stale_action")
	assert_eq(decision.action_generation, replacement)
	assert_eq(decision.action_status, C_NpcDecision.ActionStatus.RUNNING)
	assert_false(person.phase_complete)


## An accepted execution and a cancelled result are visible without an independent state writer.
func test_execution_diagnostics_read_existing_component_state() -> void:
	var body: E_DistrictNpc = _departure()
	var person: NpcRecord = _district.people[0]
	var generation: int = NpcScheduleActionService.accept_schedule(body, person)
	var state: Dictionary[String, Variant] = NpcDecisionDiagnostics.actor_state(body)
	assert_eq(state["action_status"], "ACCEPTED")
	assert_eq(state["action_generation"], generation)
	NpcScheduleActionService.cancel_schedule(body, &"explicit_cancel")
	state = NpcDecisionDiagnostics.actor_state(body)
	assert_eq(state["action_status"], "CANCELLED")
	assert_eq(state["action_reason"], "explicit_cancel")
	assert_false(person.phase_complete)


## Same-world restore drops transient actions and budget counters while retaining the obligation.
func test_restore_invalidates_pending_action_and_derived_budget() -> void:
	var body: E_DistrictNpc = _departure()
	var person: NpcRecord = _district.people[0]
	var obligation: StringName = person.goal_id
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	var previous_generation: int = decision.action_generation
	_district.decision_cursor = person.npc_id
	_district.decision_max_wait_ticks = 100
	DistrictPopulationService.restore_participation()
	assert_same(body.get_component(C_NpcDecision), decision)
	assert_eq(decision.action_status, C_NpcDecision.ActionStatus.NONE)
	assert_gt(decision.action_generation, previous_generation)
	assert_eq(_district.decision_cursor, &"")
	assert_eq(_district.decision_max_wait_ticks, 0)
	assert_eq(person.goal_id, obligation)
	assert_false(person.phase_complete)
	_run_branch(body, C_NpcDecision.Owner.SCHEDULE, 0.2)
	assert_eq(decision.action_status, C_NpcDecision.ActionStatus.RUNNING)
#endregion
