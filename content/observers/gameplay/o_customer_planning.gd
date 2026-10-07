extends Observer
## Prepares visits only for explicit bootstrap/day/registration facts and planning commands.
class_name O_CustomerPlanning

#region Reactive boundaries
## Declares the sole planning command handler and the committed day/registration consumers.
func sub_observers() -> Array[Array]:
	return [
		[q.with_all([C_CustomerFlow, C_DayCycle]).on_event(DayPhaseChanged.EVENT), _on_day],
		[q.on_event(CustomerPlanningRequest.EVENT), _on_request],
		[q.on_event(PackageScanResult.EVENT), _on_registered],
	]


func _on_day(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var transition: DayPhaseChanged = payload as DayPhaseChanged
	assert(transition != null)
	cmd.add_custom(_prepare_session.bind(session, transition))


func _on_request(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var request: CustomerPlanningRequest = payload as CustomerPlanningRequest
	assert(request != null)
	cmd.add_custom(_execute_request.bind(request, session))


func _on_registered(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var result: PackageScanResult = payload as PackageScanResult
	if result == null or result.outcome != PackageScanResult.Outcome.REGISTERED:
		return
	cmd.add_custom(_reactivate_current)


func _reactivate_current() -> void:
	var flow: C_CustomerFlow = CustomerFlowService.current()
	var cycle: C_DayCycle = DayPhaseService.current()
	if flow != null and cycle != null:
		_reactivate(flow, cycle.day_index)


func _prepare_session(session: Entity, transition: DayPhaseChanged) -> void:
	# The queued fact may outlive its session or be superseded by a later phase.
	if not EntityAvailability.contains(session, _world):
		return
	var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	if cycle.day_index != transition.day_index or cycle.phase != transition.phase:
		return
	if flow.planning_day == cycle.day_index and flow.planning_phase == int(cycle.phase):
		return

	var wallet: C_Wallet = WalletService.current()
	var payment: int = (
		wallet.policy.delivery_payment if wallet != null and wallet.policy != null else 0
	)
	_plan_day(flow, cycle.day_index, payment)
	if cycle.phase == C_DayCycle.Phase.MORNING:
		flow.arrival_cooldown_seconds = 0.0
		_reconcile_morning(flow, cycle, wallet)
	_reactivate(flow, cycle.day_index)

	flow.planning_day = cycle.day_index
	flow.planning_phase = int(cycle.phase)


func _execute_request(request: CustomerPlanningRequest, session: Entity) -> void:
	# Runtime commands retain their owning session across the buffer boundary.
	# Null is reserved for isolated data fixtures, which deliberately have no Entity owner.
	if session != null:
		if not EntityAvailability.contains(session, _world):
			request.rejection_reason = &"session_unavailable"
			request.completed = true
			return
		var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		if (
			session.get_component(C_CustomerFlow) != request.flow
			or (request.kind == CustomerPlanningRequest.Kind.PLAN_DAY
				and cycle.day_index != request.day_index)
		):
			request.rejection_reason = &"stale_context"
			request.completed = true
			return

	match request.kind:
		CustomerPlanningRequest.Kind.PLAN_DAY:
			_plan_day(request.flow, request.day_index, request.payment)
		CustomerPlanningRequest.Kind.RECONCILE_MORNING:
			request.affected_visits = _reconcile_morning(request.flow, request.cycle, request.wallet)
		CustomerPlanningRequest.Kind.REACTIVATE_FOLLOWUPS:
			request.affected_visits = _reactivate(request.flow, request.day_index)
	request.completed = true
#endregion

#region Day planning and reconciliation
func _plan_day(flow: C_CustomerFlow, day: int, payment: int) -> void:
	var schedule: DEF_CustomerSchedule = flow.schedule
	if schedule == null or schedule.supply == null:
		return

	if DistrictPopulationService.current() != null:
		flow.planned_through_day = maxi(flow.planned_through_day, day)
		return

	while flow.planned_through_day < day:
		flow.planned_through_day += 1
		var supply_day: int = flow.planned_through_day
		for event: DEF_CustomerEvent in schedule.events:
			if event.arrival_delay_days < 0 or event.customer == null:
				continue

			for definition: DEF_Package in schedule.supply.packages:
				if definition.key != event.package_key:
					continue

				CustomerFlowService.create_visit(flow, definition, event, supply_day, payment)


func _reconcile_morning(
	flow: C_CustomerFlow,
	cycle: C_DayCycle,
	wallet: C_Wallet,
) -> int:
	if (
		cycle.phase != C_DayCycle.Phase.MORNING
		or cycle.day_index <= 1
	):
		return 0

	var ledger: C_PackageLedger = PackageRegistrationService.ledger()
	if ledger == null:
		return 0

	var overdue_count: int = 0
	for visit: CustomerVisit in flow.visits:
		if (
			not visit.requires_registered_package
			or visit.arrival_day >= cycle.day_index
			or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
			or visit.declaration != CustomerVisit.Declaration.NONE
			or (visit.registration_overdue_day > 0 and visit.registration_penalty_committed)
		):
			continue
		var record: PackageRegistrationRecord = PackageHistoryService.record_for(
			visit.package_id, ledger
		)
		if record == null or (record.active and record.number > 0):
			continue

		var parcel: Entity = CustomerFlowService.parcel_for(visit.package_id)
		if parcel != null:
			var state: C_PackageState = parcel.get_component(C_PackageState) as C_PackageState
			if state == null or state.registration != C_PackageState.Registration.UNREGISTERED:
				continue

			var identity: C_Package = parcel.get_component(C_Package) as C_Package
			if identity != null and visit.package_history_id.is_empty():
				visit.package_history_id = identity.history_id

		if CustomerOutcomeService.mark_registration_overdue(visit, cycle.day_index):
			overdue_count += 1
		CustomerOutcomeService.settle_registration_overdue(visit, wallet, cycle.day_index)
	return overdue_count


func _reactivate(flow: C_CustomerFlow, day: int) -> int:
	var reactivated: int = 0
	for visit: CustomerVisit in flow.visits:
		if (
			not visit.finished
			or visit.next_followup_day <= 0
			or visit.next_followup_day > day
			or visit.declaration != CustomerVisit.Declaration.NONE
			or visit.complaint != null
			or visit.customer_dead
		):
			continue
		if visit.requires_registered_package and not CustomerFlowService.arrival_allowed(visit):
			continue

		visit.started = false
		visit.finished = false
		visit.finished_day = 0
		visit.next_followup_day = 0
		visit.followup_committed = false
		visit.actual = CustomerVisit.Actual.NOT_RESOLVED
		visit.aggressive = false
		reactivated += 1
	return reactivated
#endregion
