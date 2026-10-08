extends GutTest
## Proves discrete planning, morning gates and registration-triggered followups in real World.

var _world: World
var _session: Entity
var _flow: C_CustomerFlow
var _cycle: C_DayCycle
var _wallet: C_Wallet
var _planning: O_CustomerPlanning

#region Fixture
## Installs the real discrete handler and scheduling owner.
func before_each() -> void:
	_world = World.new()
	add_child(_world)
	ECS.world = _world
	_session = Entity.new()
	_session.component_resources = [
		C_CustomerFlow.new(), C_DayCycle.new(), C_Wallet.new(), C_PackageLedger.new()
	]
	_world.add_entity(_session)
	_flow = _session.get_component(C_CustomerFlow) as C_CustomerFlow
	_cycle = _session.get_component(C_DayCycle) as C_DayCycle
	_wallet = _session.get_component(C_Wallet) as C_Wallet
	_wallet.policy = DEF_Economy.new()
	_wallet.policy.missed_registration_percent = 300
	_planning = O_CustomerPlanning.new()
	_world.add_observer(_planning)
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
	_world.add_entity(parcel)
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
	assert_eq(PackageRegistrationService.register_package(parcel).outcome,
		PackageScanResult.Outcome.REGISTERED)
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
