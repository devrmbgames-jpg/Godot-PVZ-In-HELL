extends Observer
## Reconciles visit transactions on committed changes and complaints on calendar/bootstrap facts.
class_name O_CustomerOutcomes

#region Reactive boundaries
## Declares record-change and committed calendar inputs; no frame polling remains.
func sub_observers() -> Array[Array]:
	return [
		[q.with_all([C_CustomerAgent]).on_event(NpcSocialReactionCommitted.EVENT), _on_social_reaction],
		[q.with_all([C_CustomerFlow, C_DayCycle]).on_event(CustomerOutcomeChanged.EVENT), _on_change],
		[q.with_all([C_CustomerFlow, C_DayCycle]).on_event(DayPhaseChanged.EVENT), _on_day],
		[q.with_all([C_Challenge, C_CustomerAgent]).on_event(ChallengeSessionClosed.EVENT), _on_closed],
	]


func _on_social_reaction(_event: Variant, subject: Entity, payload: Variant = null) -> void:
	var fact: NpcSocialReactionCommitted = payload as NpcSocialReactionCommitted
	assert(fact != null)
	var visit: CustomerVisit = CustomerFlowQueries.visit_for(subject)
	if visit != null:
		visit.aggressive = fact.reaction == NpcMemory.Reaction.ATTACK and fact.combat_active


func _on_change(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var fact: CustomerOutcomeChanged = payload as CustomerOutcomeChanged
	assert(fact != null)
	var captured_flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var captured_cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	cmd.add_custom(_reconcile_visit.bind(weakref(session), fact.visit_id, captured_flow, captured_cycle))


func _on_day(_event: Variant, session: Entity, payload: Variant = null) -> void:
	var fact: DayPhaseChanged = payload as DayPhaseChanged
	assert(fact != null)
	var captured_flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var captured_cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	cmd.add_custom(_reconcile_day.bind(weakref(session), fact, captured_flow, captured_cycle))


func _on_closed(_event: Variant, subject: Entity, payload: Variant = null) -> void:
	assert(payload is ChallengeSessionClosed)
	var captured_agent: C_CustomerAgent = subject.get_component(C_CustomerAgent) as C_CustomerAgent
	cmd.add_custom(_reconcile_appearance.bind(weakref(subject), captured_agent))
#endregion

#region Transaction reconciliation
func _reconcile_appearance(subject_reference: WeakRef, captured_agent: C_CustomerAgent) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var subject: Entity = subject_reference.get_ref() as Entity

	if not EntityAvailability.contains(subject, _world) \
			or subject.get_component(C_CustomerAgent) != captured_agent:
		return

	var agent: C_CustomerAgent = subject.get_component(C_CustomerAgent) as C_CustomerAgent
	if agent == null:
		return
	var visit: CustomerVisit = CustomerFlowQueries.find_visit(agent.visit_id)
	var cycle: C_DayCycle = DayPhaseQueries.current()
	if visit != null and cycle != null:
		_reconcile(visit, WalletService.current(), cycle.day_index)


func _reconcile_visit(session_reference: WeakRef, visit_id: StringName, captured_flow: C_CustomerFlow, captured_cycle: C_DayCycle) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if not EntityAvailability.contains(session, _world) \
			or session.get_component(C_CustomerFlow) != captured_flow \
			or session.get_component(C_DayCycle) != captured_cycle:
		return

	var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	for visit: CustomerVisit in flow.visits:
		if visit.visit_id == visit_id:
			_reconcile(visit, WalletService.current(), cycle.day_index)
			return


func _reconcile_day(session_reference: WeakRef, fact: DayPhaseChanged, captured_flow: C_CustomerFlow, captured_cycle: C_DayCycle) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var session: Entity = session_reference.get_ref() as Entity

	if not EntityAvailability.contains(session, _world) \
			or session.get_component(C_CustomerFlow) != captured_flow \
			or session.get_component(C_DayCycle) != captured_cycle:
		return

	var cycle: C_DayCycle = session.get_component(C_DayCycle) as C_DayCycle
	if cycle.day_index != fact.day_index or cycle.phase != fact.phase:
		return
	var flow: C_CustomerFlow = session.get_component(C_CustomerFlow) as C_CustomerFlow
	var wallet: C_Wallet = WalletService.current()
	for visit: CustomerVisit in flow.visits:
		_reconcile(visit, wallet, cycle.day_index)


func _reconcile(visit: CustomerVisit, wallet: C_Wallet, day: int) -> void:
	CustomerOutcomeService.settle(visit, wallet, day)
	if visit.complaint != null and visit.complaint.outcome == CustomerComplaint.Outcome.PENDING:
		CustomerOutcomeService.resolve_complaint(visit, wallet, day)
#endregion
