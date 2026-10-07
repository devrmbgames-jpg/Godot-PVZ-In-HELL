extends "res://tests/gut/test_district_population.gd"
## Exercises actual lifecycle reactions, queued receipts and retained-body/save boundaries.

const SAVE_PATH: String = "user://gut_district_lifecycle_gate.pvzh"

#region Fixture boundaries
func _lifecycle() -> O_DistrictLifecycle:
	for observer: Observer in _world.observers:
		if observer is O_DistrictLifecycle:
			return observer as O_DistrictLifecycle
	assert(false, "Fixture must install the real district lifecycle owner")
	return null


func _publish_calendar() -> void:
	var session: Entity = _world.query.with_all([C_District, C_DayCycle]).execute_one()
	_world.emit_event(DayPhaseChanged.EVENT, session, DayPhaseChanged.from_cycle(DayPhaseService.current()))


## Removes only this fixture's save slot before freeing the actual World.
func after_each() -> void:
	for path: String in [SAVE_PATH, SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	super.after_each()
#endregion

#region Calendar and death facts
## Replayed calendar facts preserve completed goals, reaction memory and conflict budget.
func test_calendar_fact_reconciles_once_without_frame_polling() -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.DAY
	_publish_calendar()
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var awareness: C_NpcAwareness = body.get_component(C_NpcAwareness) as C_NpcAwareness
	person.phase_complete = true
	awareness.called_out = true
	_district.ambient_conflicts = 1
	_publish_calendar()
	assert_true(person.phase_complete)
	assert_true(awareness.called_out)
	assert_eq(_district.ambient_conflicts, 1)

	cycle.phase = C_DayCycle.Phase.EVENING
	_publish_calendar()
	assert_false(person.phase_complete)
	assert_false(awareness.called_out)
	assert_eq(_district.ambient_conflicts, 0)
	assert_eq(person.planned_phase, int(C_DayCycle.Phase.EVENING))


## Body death is reconciled without a district tick and retains terminal identity history.
func test_death_match_commits_once_and_keeps_the_retained_body() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	body.add_component(C_Death.new())
	assert_eq(person.death_day, 1)
	assert_eq(person.placement, NpcRecord.Placement.DEAD)
	assert_false(body.enabled)
	assert_same(DistrictPopulationService.body_for(person.npc_id), body)
	_publish_calendar()
	assert_eq(person.death_day, 1)
	assert_eq(_district.people.size(), 12)


## The established night boundary delays death bookkeeping until a daytime calendar fact.
func test_night_death_is_reconciled_at_the_next_daytime_boundary() -> void:
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.NIGHT
	var person: NpcRecord = _district.people[0]
	DistrictPopulationService.body_for(person.npc_id).add_component(C_Death.new())
	assert_eq(person.death_day, 0)
	cycle.day_index = 2
	cycle.phase = C_DayCycle.Phase.MORNING
	_publish_calendar()
	assert_eq(person.death_day, 2)
#endregion

#region Queued command receipts
## A queued assignment cannot mutate the replacement record after restore/replacement.
func test_queued_plan_rejects_replaced_aggregate_record() -> void:
	_lifecycle().command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var request: NpcPhasePlanRequest = DistrictPopulationService.request_phase(body, 2, C_DayCycle.Phase.DAY)
	assert_false(request.completed)
	assert_eq(person.planned_day, 1)
	var replacement: NpcRecord = person.duplicate() as NpcRecord
	_district.people[0] = replacement
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_false(request.succeeded)
	assert_eq(request.rejection_reason, &"stale_record")
	assert_eq(replacement.planned_day, 1)


## A higher priority branch prevents an older scheduled completion from hiding its body.
func test_queued_completion_rejects_interrupted_decision() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var decision: C_NpcDecision = body.get_component(C_NpcDecision) as C_NpcDecision
	decision.intent_owner = C_NpcDecision.Owner.SCHEDULE
	_lifecycle().command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: NpcScheduleCompletionRequest = DistrictPopulationService.request_phase_completion(body, NpcRecord.Placement.OUTSIDE)
	assert_false(request.completed)
	decision.intent_owner = C_NpcDecision.Owner.EMERGENCY
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_false(request.succeeded)
	assert_eq(request.rejection_reason, &"decision_interrupted")
	assert_false(person.phase_complete)
	assert_true(body.enabled)


## A replacement macro goal cannot be completed by the previous goal's queued receipt.
func test_queued_completion_rejects_superseded_goal() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	_lifecycle().command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: NpcScheduleCompletionRequest = DistrictPopulationService.request_phase_completion(body)
	person.planned_phase = int(C_DayCycle.Phase.DAY)
	_world.flush_command_buffers()
	assert_false(request.succeeded)
	assert_eq(request.rejection_reason, &"stale_goal")
	assert_false(person.phase_complete)


## The native completion leaf remains RUNNING until the actual lifecycle commit.
func test_native_completion_waits_for_receipt_before_completion() -> void:
	var person: NpcRecord = _district.people[0]
	var body: E_DistrictNpc = DistrictPopulationService.body_for(person.npc_id)
	var task: BTAction = BTAction.new()
	task.set_script(load("res://content/ai/tasks/bt_npc_finish_schedule.gd") as Script)
	task.set("intent_owner", C_NpcDecision.Owner.SCHEDULE)
	var tree: BehaviorTree = BehaviorTree.new()
	tree.root_task = task
	var runner: BTPlayer = body.get_node("Brain") as BTPlayer
	runner.behavior_tree = tree
	_lifecycle().command_buffer_flush_mode = Observer.FlushMode.MANUAL
	assert_true(NpcBrainService.update_tree(body, 0.2))
	assert_eq(runner.get_bt_instance().get_root_task().get_status(), BTTask.RUNNING)
	assert_false(person.phase_complete)
	_world.flush_command_buffers()
	assert_true(person.phase_complete)
#endregion

#region Morning preparation and persistence
## Two pending morning requests prepare one replacement and resolve only after actual commit.
func test_pending_morning_requests_do_not_duplicate_resettlement() -> void:
	for index: int in 2:
		var person: NpcRecord = _district.people[index]
		DistrictPopulationService.mark_dead(person, DistrictPopulationService.body_for(person.npc_id), 1)
	_lifecycle().command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var first: DistrictMorningPreparationRequest = DistrictPopulationService.prepare_morning(3)
	var retry: DistrictMorningPreparationRequest = DistrictPopulationService.prepare_morning(3)
	assert_false(first.completed)
	assert_eq(_district.prepared_morning, 1)
	assert_eq(_district.people.size(), 12)
	_world.flush_command_buffers()
	assert_true(first.succeeded)
	assert_true(retry.succeeded)
	assert_eq(_district.prepared_morning, 3)
	assert_eq(_district.people.size(), 13)


## Calendar changes invalidate a previously queued future-morning operation.
func test_pending_preparation_rejects_superseded_calendar_context() -> void:
	_lifecycle().command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: DistrictMorningPreparationRequest = DistrictPopulationService.prepare_morning(2)
	DayPhaseService.current().phase = C_DayCycle.Phase.DAY
	_world.flush_command_buffers()
	assert_false(request.succeeded)
	assert_eq(request.rejection_reason, &"stale_calendar")
	assert_eq(_district.prepared_morning, 1)


## Night capture cannot mark the save ready while future morning placement remains queued.
func test_night_save_waits_for_preparation_and_then_retries_without_resetting() -> void:
	var session: Entity = _world.query.with_all([C_District]).execute_one()
	session.add_component(C_Autosave.new())
	var state: C_Autosave = session.get_component(C_Autosave) as C_Autosave
	state.path = SAVE_PATH
	var cycle: C_DayCycle = DayPhaseService.current()
	cycle.phase = C_DayCycle.Phase.NIGHT
	_lifecycle().command_buffer_flush_mode = Observer.FlushMode.MANUAL
	NightSaveService.process(session, cycle, state, 0.2)
	assert_eq(state.last_error, ERR_BUSY)
	assert_false(cycle.night_ready)
	assert_eq(state.last_saved_morning, 0)
	assert_eq(_district.prepared_morning, 1)
	assert_false(FileAccess.file_exists(SAVE_PATH))
	_world.flush_command_buffers()
	assert_eq(_district.prepared_morning, 2)
	state.retry_remaining = 0.0
	NightSaveService.process(session, cycle, state, 0.2)
	assert_eq(state.last_error, OK)
	assert_true(cycle.night_ready)
	assert_eq(state.last_saved_morning, 2)
	assert_eq(state.started_night, 1)
	assert_true(FileAccess.file_exists(SAVE_PATH))


## Current-format restore invalidates derived reconciliation state and bootstrap rebuilds it.
func test_restore_invalidates_calendar_cache_without_serializing_it() -> void:
	_publish_calendar()
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 2)
	assert_true(WorldSnapshotService.restore(snapshot, _root))
	assert_eq(_district.lifecycle_day, 0)
	assert_eq(_district.lifecycle_phase, -1)
	var bootstrap: S_District = S_District.new()
	bootstrap.group = "GamePlay"
	_world.add_system(bootstrap, true)
	_world.process(0.0, "GamePlay")
	assert_eq(_district.lifecycle_day, 2)
	assert_eq(_district.lifecycle_phase, int(C_DayCycle.Phase.MORNING))
	var encoded: Dictionary = SaveDataCodec.component_data(_district)
	assert_false((encoded.fields as Dictionary).has("lifecycle_day"))
	assert_false((encoded.fields as Dictionary).has("lifecycle_phase"))
#endregion
