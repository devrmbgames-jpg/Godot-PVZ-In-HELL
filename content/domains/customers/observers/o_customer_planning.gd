extends Observer
## Prepares visits only for explicit bootstrap/day/registration facts and planning commands.
class_name O_CustomerPlanning

# Handler удерживает receipts до исполнения/реконструкции;
# flow хранит только WeakRef для coalescing.
var _pending_requests: Array[CustomerPlanningRequest] = []


#region Reactive boundaries
## Declares the sole planning command handler and the committed day/registration consumers.
func sub_observers() -> Array[Array]:
	return [
		[q.with_all([C_CustomerFlow, C_DayCycle]).on_event(DayPhaseChanged.EVENT), _on_day],
		[q.on_event(CustomerPlanningRequest.EVENT), _on_request],
		[q.on_event(WorldReconstructionStarted.EVENT), _on_reconstruction],
		[q.on_event(PackageScanResult.EVENT), _on_registered],
		[q.on_event(DistrictMorningPrepared.EVENT), _on_district_prepared],
		[q.on_event(NpcReturnCommitted.EVENT), _on_returned],
	]


func _on_day(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var transition: DayPhaseChanged = payload as DayPhaseChanged
	assert(transition != null)
	var captured_flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var captured_cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	cmd.add_custom(
		_prepare_session.bind(weakref(session), transition, captured_flow, captured_cycle)
	)


func _on_request(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var request: CustomerPlanningRequest = payload as CustomerPlanningRequest
	assert(request != null)
	_pending_requests.append(request)
	cmd.add_custom(_execute_request.bind(request, weakref(session) if session != null else null))


func _on_reconstruction(_event: Variant, _session: Entity, _payload: Variant = null) -> void:
	# This synchronous retirement runs before persistence clears every CommandBuffer.
	for request: CustomerPlanningRequest in _pending_requests:
		if not request.completed:
			request.rejection_reason = &"reconstruction_started"
			request.completed = true
	_pending_requests.clear()
	for session: Entity in _world.query.with_all([C_CustomerFlow]).execute():
		var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
		flow.planning_generation += 1
		flow.planning_request = null


func _on_registered(_event: Variant, _entity: Entity, payload: Variant = null) -> void:
	var result: PackageScanResult = payload as PackageScanResult
	if result == null or result.outcome != PackageScanResult.Outcome.REGISTERED:
		return
	cmd.add_custom(_reactivate_current)


func _reactivate_current() -> void:
	NpcDeliveryOfferService.refresh()
	var flow: C_CustomerFlow = CustomerFlowQueries.current()
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if flow != null and cycle != null:
		_reactivate(flow, cycle.day_index)


func _prepare_session(
	session_reference: WeakRef,
	transition: DayPhaseChanged,
	captured_flow: C_CustomerFlow,
	captured_cycle: C_DayCycle,
) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if (
		not EntityAvailability.contains(session, _world)
		or session.get_component(C_CustomerFlow) != captured_flow
		or session.get_component(C_DayCycle) != captured_cycle
	):
		return

	# The queued fact may outlive its session or be superseded by a later phase.
	var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	if cycle.day_index != transition.day_index or cycle.phase != transition.phase:
		return
	if flow.planning_day == cycle.day_index and flow.planning_phase == int(cycle.phase):
		return

	_prepare_current(flow, cycle)


func _prepare_current(flow: C_CustomerFlow, cycle: C_DayCycle) -> void:
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


func _execute_request(request: CustomerPlanningRequest, session_reference: WeakRef) -> void:
	_pending_requests.erase(request)
	if request.completed:
		return
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = (
		session_reference.get_ref() as Entity if session_reference != null else null
	)

	if session_reference != null and session == null:
		request.rejection_reason = &"session_unavailable"
		request.completed = true
		return

	# Runtime commands retain their owning session across the buffer boundary.
	# Null is reserved for isolated data fixtures, which deliberately have no Entity owner.
	if session != null:
		if ECS.world != _world or not EntityAvailability.contains(session, _world):
			request.rejection_reason = &"session_unavailable"
			request.completed = true
			return
		var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
		if (
			session.get_component(C_CustomerFlow) != request.flow
			or cycle == null
			or (
				request.kind == CustomerPlanningRequest.Kind.RECONCILE_SESSION
				and (
					cycle != request.cycle or cycle.day_index != request.day_index
					or cycle.phase != request.phase
					or request.flow.planning_generation != request.generation
				)
			)
			or (
				request.kind == CustomerPlanningRequest.Kind.PLAN_DAY
				and cycle.day_index != request.day_index
			)
		):
			request.rejection_reason = &"stale_context"
			request.completed = true
			return

	if request.kind == CustomerPlanningRequest.Kind.RECONCILE_SESSION and session == null:
		request.rejection_reason = &"session_unavailable"
		request.completed = true
		return

	match request.kind:
		CustomerPlanningRequest.Kind.RECONCILE_SESSION:
			if (
				request.flow.planning_day != request.day_index
				or request.flow.planning_phase != int(request.phase)
			):
				_prepare_current(request.flow, request.cycle)
		CustomerPlanningRequest.Kind.PLAN_DAY:
			_plan_day(request.flow, request.day_index, request.payment)
		CustomerPlanningRequest.Kind.RECONCILE_MORNING:
			request.affected_visits = _reconcile_morning(
				request.flow,
				request.cycle,
				request.wallet,
			)
		CustomerPlanningRequest.Kind.REACTIVATE_FOLLOWUPS:
			request.affected_visits = _reactivate(request.flow, request.day_index)
	request.completed = true
	if request.kind == CustomerPlanningRequest.Kind.RECONCILE_SESSION:
		_world.emit_event(CustomerPlanningRequest.RECONCILED, session, request)
#endregion


#region Day planning and reconciliation
func _plan_day(flow: C_CustomerFlow, day: int, payment: int) -> void:
	var schedule: DEF_CustomerSchedule = flow.schedule
	if schedule == null or schedule.supply == null:
		return

	if NpcPopulationQueries.current() != null:
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


func _reconcile_morning(flow: C_CustomerFlow, cycle: C_DayCycle, wallet: C_Wallet) -> int:
	if (cycle.phase != C_DayCycle.Phase.MORNING or cycle.day_index <= 1):
		return 0

	var ledger: C_PackageLedger = PackageQueries.ledger()
	if ledger == null:
		return 0

	var overdue_count: int = 0
	for visit: CustomerVisit in flow.visits:
		if (
			not visit.requires_registered_package or visit.arrival_day >= cycle.day_index
			or visit.actual != CustomerVisit.Actual.NOT_RESOLVED
			or visit.declaration != CustomerVisit.Declaration.NONE
			or (visit.registration_overdue_day > 0 and visit.registration_penalty_committed)
		):
			continue
		var record: PackageRegistrationRecord = PackageHistoryService.record_for(
			visit.package_id,
			ledger,
		)
		if record == null or (record.active and record.number > 0):
			continue

		var parcel: Entity = PackageQueries.find_live_package(visit.package_id)
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
			not visit.finished or visit.next_followup_day <= 0 or visit.absence_sequence > 0
			or visit.next_followup_day > day or visit.declaration != CustomerVisit.Declaration.NONE
			or visit.complaint != null or visit.customer_dead
		):
			continue
		var person: NpcRecord = NpcPopulationQueries.person_for(visit.customer_id)
		if person != null and person.death_day > 0:
			continue
		if visit.requires_registered_package and not CustomerFlowQueries.arrival_allowed(visit):
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


#region Dependent morning preparation
func _on_returned(_event: Variant, body: Entity, payload: Variant = null) -> void:
	var fact: NpcReturnCommitted = payload as NpcReturnCommitted
	assert(fact != null)
	cmd.add_custom(_resume_returned.bind(weakref(body), fact))


func _resume_returned(body_reference: WeakRef, fact: NpcReturnCommitted) -> void:
	var body: E_DistrictNpc = body_reference.get_ref() as E_DistrictNpc
	if (
		ECS.world != _world or body == null or not _world.entity_to_archetype.has(body)
		or NpcPopulationQueries.current() != fact.district
		or NpcPopulationQueries.body_for(fact.npc_id) != body
	):
		return
	var person: NpcRecord = NpcPopulationQueries.person_for(fact.npc_id)
	var episode: NpcDeathRecord = NpcLifeRules.episode_for(person, fact.sequence)
	if person.death_day != 0 or episode == null or episode.returned_day != fact.day_index:
		return
	CustomerVisitLifecycle.resume_after_return(fact.npc_id, fact.sequence, fact.day_index)


func _on_district_prepared(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var fact: DistrictMorningPrepared = payload as DistrictMorningPrepared
	assert(fact != null)
	cmd.add_custom(_prepare_offers.bind(weakref(session), fact))


func _prepare_offers(session_reference: WeakRef, fact: DistrictMorningPrepared) -> void:
	var session: Entity = session_reference.get_ref() as Entity
	if not EntityAvailability.contains(session, _world):
		return
	if (
		session.get_component(C_District) != fact.district
		or session.get_component(C_DayCycle) != fact.cycle
	):
		return
	if fact.cycle.day_index != fact.context_day or fact.cycle.phase != fact.context_phase:
		return
	if fact.district.prepared_morning != fact.day_index:
		return

	# Night capture already drains all structural/outcome work before taking its immutable snapshot.
	NpcDeliveryOfferService.prepare_day(fact.day_index)
#endregion
