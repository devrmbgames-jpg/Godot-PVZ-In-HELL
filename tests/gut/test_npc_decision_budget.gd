extends "res://tests/gut/test_npc_scheduling.gd"
## Verifies capped production due work and coalesced fair wakes without a separate scheduler.


#region Burst and fairness acceptance
## Continuous duplicate wakes do not grow a queue or starve later stable identities.
func test_burst_wakes_respect_cap_and_bound_every_actor_wait() -> void:
	_district.definition = _district.definition.duplicate() as DEF_District
	_district.definition.decision_work_units = 2
	_district.definition.decision_interval = 0.8
	var actors: Array[E_DistrictNpc] = []
	for index: int in _district.people.size():
		var body: E_DistrictNpc = _stage(index, Vector3(float(index) * 3.0, 0, 0))
		actors.append(body)
		NpcDecisionService.request_wake(body, &"burst")
	_owners()
	var processed: Dictionary[StringName, bool] = { }
	var passes: int = ceili(float(actors.size()) / float(_district.definition.decision_work_units))
	for pass_index: int in passes:
		for duplicate_wake: int in 100:
			NpcDecisionService.request_wake(actors[0], &"burst")
		_world.process(0.01, "npc_scheduling")
		assert_lte(_district.decisions_processed, _district.definition.decision_work_units)
		assert_eq(
			_district.decisions_due,
			_district.decisions_processed + _district.decisions_deferred,
		)
		for actor: E_DistrictNpc in actors:
			var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
			if decision.selection_reason == &"burst" and not decision.wake_requested:
				var identity: C_NpcIdentity = actor.get_component(C_NpcIdentity) as C_NpcIdentity
				processed[identity.npc_id] = true
	assert_eq(
		processed.size(),
		actors.size(),
		"Every captured actor must run within ceil(due/cap) passes",
	)
	assert_lte(
		_district.decision_max_wait_ticks,
		GameTimeRules.duration_ticks(float(passes) * 0.01),
	)
	# Stop the continuous wake producer, then drain its final coalesced request.
	_world.process(0.01, "npc_scheduling")
	assert_eq(_district.decisions_deferred, 0)
	print(
		"NPC budget acceptance: actors=%d cap=%d passes=%d max_wait_ticks=%d deferred=%d"
		% [
			actors.size(),
			_district.definition.decision_work_units,
			passes,
			_district.decision_max_wait_ticks,
			_district.decisions_deferred,
		]
	)


## Urgent coalesced wakes invalidate a queued old step once, rather than at every duplicate event.
func test_urgent_wake_coalesces_and_invalidates_old_step_once() -> void:
	_isolate(0, 0)
	var actor: E_DistrictNpc = _stage(0)
	var decision: C_NpcDecision = actor.get_component(C_NpcDecision) as C_NpcDecision
	decision.scheduled_delta = 0.25
	var previous_generation: int = decision.lifecycle_generation
	for duplicate_wake: int in 100:
		NpcDecisionService.request_wake(actor, &"urgent_fact", true)
	assert_eq(decision.lifecycle_generation, previous_generation + 1)
	assert_eq(decision.scheduled_delta, 0.0)
	assert_true(decision.wake_requested)
	_owners()
	_world.process(0.01, "npc_scheduling")
	assert_false(decision.wake_requested)
	assert_false(decision.wake_urgent)
	assert_eq(decision.selection_reason, &"urgent_fact")
	assert_eq(_district.decisions_processed, 1)


## Stable cursor selection does not rely on mutable roster/archetype iteration order.
func test_cursor_keeps_fairness_when_roster_order_changes() -> void:
	_district.definition = _district.definition.duplicate() as DEF_District
	_district.definition.decision_work_units = 1
	var actors: Array[E_DistrictNpc] = []
	for index: int in _district.people.size():
		var body: E_DistrictNpc = _stage(index)
		actors.append(body)
		NpcDecisionService.request_wake(body, &"reorder")
	_owners()
	var selected: Dictionary[StringName, bool] = { }
	for pass_index: int in actors.size():
		_district.people.reverse()
		_world.process(0.01, "npc_scheduling")
		selected[_district.decision_cursor] = true
	assert_eq(selected.size(), actors.size())
	assert_eq(_district.decisions_deferred, 0)
#endregion
