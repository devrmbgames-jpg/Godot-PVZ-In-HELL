extends GutTest
## Proves discrete planning, morning gates and registration-triggered followups in real World.

var _world: World
var _session: Entity
var _flow: C_CustomerFlow
var _cycle: C_DayCycle
var _wallet: C_Wallet
var _planning: O_CustomerPlanning
var _spy: CalendarSpy


## Records real event delivery and verifies that calendar subscribers see committed authority.
class CalendarSpy extends Observer:
	## Immutable facts seen by a foreign calendar consumer.
	var facts: Array[DayPhaseChanged] = []
	## Explicit Customers preparation submissions.
	var requests: Array[CustomerPlanningRequest] = []
	## False if a producer published before mutation.
	var committed: bool = true

	func sub_observers() -> Array[Array]:
		return [
			[q.on_event(DayPhaseChanged.EVENT), _on_phase],
			[q.on_event(CustomerPlanningRequest.EVENT), _on_request],
		]

	func _on_phase(_event: Variant, session: Entity, payload: Variant = null) -> void:
		var fact: DayPhaseChanged = payload as DayPhaseChanged
		var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		committed = committed and cycle.day_index == fact.day_index and cycle.phase == fact.phase
		facts.append(fact)

	func _on_request(_event: Variant, _session: Entity, payload: Variant = null) -> void:
		requests.append(payload as CustomerPlanningRequest)


#region Fixture
## Installs the real discrete handler and scheduling owner.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_session = Entity.new()
	_session.component_resources = [
		C_CustomerFlow.new(),
		C_DayCycle.new(),
		C_Wallet.new(),
		C_PackageLedger.new(),
	]
	_world.add_entity(_session)
	_flow = _session.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle = _session.get_component(C_DayCycle) as C_DayCycle
	_wallet = _session.get_component(C_Wallet) as C_Wallet
	_wallet.policy = DEF_Economy.new()
	_wallet.policy.missed_registration_percent = 300
	_planning = O_CustomerPlanning.new()
	_world.add_observer(_planning)
	_spy = CalendarSpy.new()
	_world.add_observer(_spy)
	var arrivals: S_CustomerFlow = S_CustomerFlow.new()
	arrivals.group = "fixture"
	_world.add_system(arrivals)


## Frees only this isolated World, without authored scenes or real save slots.
func after_each() -> void:
	_world.purge(false)
	_world.free()
	ECS.world = null


func _unregistered(id: String) -> CustomerVisit:
	var parcel: Entity = Entity.new()
	var identity: C_Package = C_Package.new()
	identity.package_id = id
	identity.definition = DEF_Package.new()
	parcel.component_resources = [identity, C_PackageState.new()]
	EntityCompositionFixture.register(_world, parcel)
	assert_not_null(PackageHistoryService.record_arrival(parcel, 1))

	var visit: CustomerVisit = CustomerVisit.new()
	visit.visit_id = StringName("visit/" + id)
	visit.package_id = id
	visit.definition = DEF_Customer.new()
	visit.accounting_value = 100
	visit.arrival_day = 1
	_flow.visits.append(visit)
	return visit
#endregion


#region Discrete planning gates
## Repeated morning frames cannot rescan new historical records as another morning entry.
func test_morning_reconciliation_runs_at_entry_instead_of_every_frame() -> void:
	_cycle.day_index = 2
	var first: CustomerVisit = _unregistered("first")
	_world.process(0.0, "fixture")
	assert_eq(first.registration_overdue_day, 2)
	assert_eq(_wallet.operations.size(), 1)

	var later: CustomerVisit = _unregistered("later")
	_world.process(0.1, "fixture")
	_world.process(0.1, "fixture")
	assert_eq(later.registration_overdue_day, 0)
	assert_eq(_wallet.operations.size(), 1)
	_cycle.day_index = 3
	_world.process(0.0, "fixture")
	assert_eq(later.registration_overdue_day, 3)
	assert_eq(_wallet.operations.size(), 2)


## A planning receipt stays pending until the sole handler's actual structural buffer flush.
func test_planning_request_is_pending_before_manual_flush_and_idempotent_after_it() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_flow.schedule = load(
		"res://content/domains/customers/definitions/def_customer_schedule_default.tres"
	) as DEF_CustomerSchedule
	var request: CustomerPlanningRequest = CustomerPlanningRequest.new()
	request.flow = _flow
	request.day_index = 1
	request.payment = 100
	_world.emit_event(CustomerPlanningRequest.EVENT, _session, request)
	assert_false(request.completed)
	assert_eq(_flow.visits.size(), 0)

	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_eq(_flow.visits.size(), 8)
	_world.emit_event(CustomerPlanningRequest.EVENT, _session, request)
	_world.flush_command_buffers()
	assert_eq(_flow.visits.size(), 8)


## Registration during the same day releases a due followup without waiting for a phase poll.
func test_registration_fact_reactivates_due_followup_in_same_phase() -> void:
	_cycle.day_index = 2
	_cycle.phase = C_DayCycle.Phase.DAY
	var visit: CustomerVisit = _unregistered("followup")
	visit.finished = true
	visit.next_followup_day = 2
	_world.process(0.0, "fixture")
	assert_true(visit.finished)

	var parcel: Entity = PackageQueries.find_live_package(visit.package_id)
	assert_eq(
		PackageRegistrationService.register_package(parcel).outcome,
		PackageScanResult.Outcome.REGISTERED,
	)
	assert_false(visit.finished)
	assert_eq(visit.next_followup_day, 0)
	assert_false(visit.started)


## Superseded queued phase facts cannot recreate visits or reset a newer session phase.
func test_queued_stale_phase_fact_is_rejected_before_preparation() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.emit_event(DayPhaseChanged.EVENT, _session, DayPhaseChanged.from_cycle(_cycle))
	_cycle.phase = C_DayCycle.Phase.DAY
	_world.flush_command_buffers()
	assert_eq(_flow.planning_day, 0)
	assert_eq(_flow.planning_phase, -1)


## Late runtime commands cannot prepare the previous day after its session advances.
func test_queued_planning_command_rejects_superseded_day() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: CustomerPlanningRequest = CustomerPlanningRequest.new()
	request.flow = _flow
	request.day_index = _cycle.day_index
	_world.emit_event(CustomerPlanningRequest.EVENT, _session, request)
	_cycle.day_index += 1
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"stale_context")
	assert_eq(_flow.planning_day, 0)
#endregion

#region Explicit bootstrap and queued recovery
## Both bootstrap owners reconcile without waking unrelated calendar subscribers.
func test_bootstrap_and_district_recovery_do_not_publish_calendar_facts() -> void:
	_session.add_component(C_District.new())
	_world.add_observer(O_DistrictLifecycle.new())
	var district_owner: S_District = S_District.new()
	district_owner.group = "fixture"
	_world.add_system(district_owner)
	_world.process(0.0, "fixture")
	assert_eq(_flow.planning_day, _cycle.day_index)
	assert_eq((_session.get_component(C_District) as C_District).lifecycle_day, _cycle.day_index)
	assert_eq(_spy.facts.size(), 0)
	assert_eq(_spy.requests.size(), 1)
	_world.process(0.0, "fixture")
	assert_eq(_spy.requests.size(), 1)


## Several real System ticks share a pending receipt instead of recursively enqueueing.
func test_manual_flush_coalesces_bootstrap_and_keeps_arrival_clock_pending() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_cycle.phase = C_DayCycle.Phase.DAY
	_flow.arrival_cooldown_seconds = 12.0
	for step: int in 4:
		_world.process(1.0, "fixture")
	assert_eq(_spy.requests.size(), 1)
	assert_false(_spy.requests[0].completed)
	assert_eq(_flow.planning_day, 0)
	assert_eq(_flow.arrival_cooldown_seconds, 12.0)
	_world.flush_command_buffers()
	assert_true(_spy.requests[0].completed)
	assert_eq(_flow.planning_phase, int(C_DayCycle.Phase.DAY))
	_world.process(1.0, "fixture")
	assert_eq(_flow.arrival_cooldown_seconds, 11.0)
	assert_eq(_spy.requests.size(), 1)
	assert_eq(_spy.facts.size(), 0)


## A rejected phase can recover in the new context after its first receipt completes.
func test_reconcile_rejects_stale_phase_and_recovers_without_republishing_calendar() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: CustomerPlanningRequest = CustomerFlowService.reconcile_session(_world, _session)
	_cycle.phase = C_DayCycle.Phase.DAY
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"stale_context")
	assert_eq(_flow.planning_day, 0)
	_world.process(0.0, "fixture")
	assert_eq(_spy.requests.size(), 2)
	_world.flush_command_buffers()
	assert_eq(_flow.planning_phase, int(C_DayCycle.Phase.DAY))
	assert_eq(_spy.facts.size(), 0)


## Calendar object identity matters even if the replacement has identical day/phase.
func test_reconcile_rejects_replaced_calendar_component() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: CustomerPlanningRequest = CustomerFlowService.reconcile_session(_world, _session)
	_session.remove_component(C_DayCycle)
	_session.add_component(C_DayCycle.new())
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"stale_context")
	assert_eq(_flow.planning_day, 0)


## Replaced aggregates cannot inherit an old queued command.
func test_reconcile_rejects_replaced_flow_component() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: CustomerPlanningRequest = CustomerFlowService.reconcile_session(_world, _session)
	_session.remove_component(C_CustomerFlow)
	var replacement: C_CustomerFlow = C_CustomerFlow.new()
	_session.add_component(replacement)
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"stale_context")
	assert_eq(replacement.planning_day, 0)
	assert_eq(_flow.planning_day, 0)


## A WeakRef queued owner is resolved before calling typed domain operations.
func test_reconcile_rejects_freed_owner_with_terminal_receipt() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: CustomerPlanningRequest = CustomerFlowService.reconcile_session(_world, _session)
	_world.remove_entity(_session)
	_session.free()
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"session_unavailable")
	assert_eq(_flow.planning_day, 0)


## A new global World cannot receive effects from an old World's queued bootstrap.
func test_reconcile_rejects_world_replacement() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: CustomerPlanningRequest = CustomerFlowService.reconcile_session(_world, _session)
	var replacement: World = World.new()
	add_child(replacement)
	ECS.world = replacement
	_world.flush_command_buffers()
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"session_unavailable")
	assert_eq(_flow.planning_day, 0)
	ECS.world = _world
	replacement.purge(false)
	replacement.free()


## Reconstruction cancels the receipt before clearing the callback, even at the same day/phase.
func test_reconstruction_completes_pending_receipt_and_invalidates_generation() -> void:
	_planning.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	var request: CustomerPlanningRequest = CustomerFlowService.reconcile_session(_world, _session)
	var activity: Dictionary[Observer, bool] = SnapshotRestoreBoundary.begin(_world)
	SnapshotRestoreBoundary.finish(_world, activity)
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"reconstruction_started")
	assert_eq(_flow.planning_generation, request.generation + 1)
	var fresh: CustomerPlanningRequest = CustomerFlowService.reconcile_session(_world, _session)
	assert_ne(fresh, request)
	_world.flush_command_buffers()
	assert_true(fresh.completed)
	assert_eq(_flow.planning_day, 1)
	assert_eq(_spy.facts.size(), 0)


## Late customer capability uses one recovery request in an already running World.
func test_late_customer_capability_prepares_once_without_calendar_publication() -> void:
	_session.remove_component(C_CustomerFlow)
	_world.process(0.0, "fixture")
	_flow = C_CustomerFlow.new()
	_session.add_component(_flow)
	_world.process(0.0, "fixture")
	_world.process(0.0, "fixture")
	assert_eq(_flow.planning_day, 1)
	assert_eq(_spy.requests.size(), 1)
	assert_eq(_spy.facts.size(), 0)


## Replay and recovery cannot duplicate visits, penalties or followup reactivation.
func test_repeated_reconcile_preserves_visits_and_committed_finances() -> void:
	_cycle.day_index = 2
	var visit: CustomerVisit = _unregistered("repeated")
	var request: CustomerPlanningRequest = CustomerFlowService.reconcile_session(_world, _session)
	assert_true(request.completed)
	assert_eq(visit.registration_overdue_day, 2)
	var balance: int = _wallet.balance
	var count: int = _flow.visits.size()
	_world.emit_event(CustomerPlanningRequest.EVENT, _session, request)
	CustomerFlowService.reconcile_session(_world, _session)
	_world.process(0.0, "fixture")
	assert_eq(_wallet.balance, balance)
	assert_eq(_wallet.operations.size(), 1)
	assert_eq(_flow.visits.size(), count)
	assert_eq(_spy.facts.size(), 0)


## Only the calendar owner publishes actual phase changes, after committing each mutation.
func test_real_calendar_transitions_publish_committed_facts_without_bootstrap_noise() -> void:
	var owner: S_DayPhase = S_DayPhase.new()
	owner.group = "calendar"
	_world.add_system(owner)
	_cycle.clock = GameClock.new()
	_cycle.require_finished_customers = false
	_cycle.require_empty_customer_room = false
	_cycle.require_all_planned_arrivals = false
	_cycle.minimum_shift_seconds = 0.0
	CustomerFlowService.reconcile_session(_world, _session)
	for kind: DayTransitionRequest.Kind in [
		DayTransitionRequest.Kind.START_SHIFT,
		DayTransitionRequest.Kind.FINISH_SHIFT,
		DayTransitionRequest.Kind.SLEEP,
	]:
		var request: DayTransitionRequest = DayTransitionRequest.new()
		request.kind = kind
		request.expected_day = _cycle.day_index
		request.expected_phase = _cycle.phase
		assert_true(DayPhaseService.submit(request))
		_world.process(0.0, "calendar")
	assert_eq(_spy.facts.size(), 3)
	assert_eq(_spy.facts[0].phase, C_DayCycle.Phase.DAY)
	assert_eq(_spy.facts[1].phase, C_DayCycle.Phase.EVENING)
	assert_eq(_spy.facts[2].phase, C_DayCycle.Phase.NIGHT)
	assert_true(_spy.committed)
#endregion


#region District receipt retirement before reconstruction
## Clearing old callbacks must finish their receipts even after aggregate replacement.
func test_reconstruction_retires_district_receipt_after_component_replacement() -> void:
	var district: C_District = C_District.new()
	_session.add_component(district)
	var lifecycle: O_DistrictLifecycle = O_DistrictLifecycle.new()
	lifecycle.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(lifecycle)
	var request: DistrictCalendarReconcileRequest = DistrictPopulationService.reconcile_calendar(
		_world, _session
	)
	assert_false(request.completed)
	_session.remove_component(C_District)
	var replacement: C_District = C_District.new()
	_session.add_component(replacement)
	var activity: Dictionary[Observer, bool] = SnapshotRestoreBoundary.begin(_world)
	SnapshotRestoreBoundary.finish(_world, activity)
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"reconstruction_started")
	var fresh: DistrictCalendarReconcileRequest = DistrictPopulationService.reconcile_calendar(
		_world, _session
	)
	_world.flush_command_buffers()
	assert_true(fresh.completed)
	assert_eq(replacement.lifecycle_day, 1)
	assert_eq(district.lifecycle_day, 0)


## A removed owner is absent from the reconstruction query, but its queued receipt still retires.
func test_reconstruction_retires_district_receipt_after_session_removal() -> void:
	_session.add_component(C_District.new())
	var lifecycle: O_DistrictLifecycle = O_DistrictLifecycle.new()
	lifecycle.command_buffer_flush_mode = Observer.FlushMode.MANUAL
	_world.add_observer(lifecycle)
	var request: DistrictCalendarReconcileRequest = DistrictPopulationService.reconcile_calendar(
		_world, _session
	)
	_world.remove_entity(_session)
	var activity: Dictionary[Observer, bool] = SnapshotRestoreBoundary.begin(_world)
	SnapshotRestoreBoundary.finish(_world, activity)
	assert_true(request.completed)
	assert_eq(request.rejection_reason, &"reconstruction_started")
	_session.free()
#endregion
