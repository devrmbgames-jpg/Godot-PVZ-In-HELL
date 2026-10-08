extends Observer
## Applies a committed challenge result to its visit once, without frame polling.
class_name O_CustomerChallengeOutcome

## An accepted customer failure requests the existing combat adapter's escalation.
signal escalation_requested(customer: Entity, actor: Entity, event: ChallengeResolution)

#region Terminal fact boundary
## Selects terminal challenge facts on bodies still participating in a customer role.
func query() -> QueryBuilder:
	return q.with_all([C_Challenge, C_CustomerAgent]).on_event(ChallengeResolution.EVENT)


## Queues the bridge's actual commit; dispatch is not consequence completion.
func each(_event: Variant, subject: Entity, payload: Variant = null) -> void:
	var resolution: ChallengeResolution = payload as ChallengeResolution
	assert(resolution != null)
	cmd.add_custom(_apply.bind(weakref(subject), resolution))


func _apply(subject_reference: WeakRef, resolution: ChallengeResolution) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var subject: Entity = subject_reference.get_ref() as Entity

	if not EntityAvailability.contains(subject, _world):
		return
	# A queued result may outlive its role or be superseded by challenge cleanup/restart.
	var state: C_Challenge = subject.get_component(C_Challenge) as C_Challenge
	var agent: C_CustomerAgent = subject.get_component(C_CustomerAgent) as C_CustomerAgent
	if state == null or agent == null or state.pending_result != resolution or state.consequences_applied:
		return
	var visit: CustomerVisit = CustomerFlowService.find_visit(agent.visit_id)
	if visit == null or visit.finished:
		return

	var applied: bool = CustomerOutcomeService.apply_challenge_result(visit, resolution)
	state.consequences_applied = true
	if applied:
		CustomerArrivalService.apply_result(subject, resolution)
	if applied and resolution.request_escalation:
		state.escalation_request = resolution
		escalation_requested.emit(subject, ChallengeService.actor_for(subject), resolution)
	CustomerOutcomeService.publish_change(visit, &"challenge_consequences_applied")
#endregion
