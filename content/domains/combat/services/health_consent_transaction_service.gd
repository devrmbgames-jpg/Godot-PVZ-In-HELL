extends RefCounted
## Explicit voluntary HP operation through common Health arithmetic and result publication.
class_name HealthConsentTransactionService


#region Synchronous voluntary Health transaction
## Preflights finite current HP and a nonlethal percentage without changing any state.
static func can_apply(change: HealthConsentChange) -> bool:
	if (
		change == null or not EntityAvailability.contains(change.target, ECS.world)
		or not change.target.enabled or change.target.has_component(C_Death)
		or change.confirmation_key.is_empty() or change.origin_id.is_empty()
		or not is_finite(change.fraction) or change.fraction <= 0.0 or change.fraction >= 1.0
	):
		return false
	var health: C_Health = change.target.get_component(C_Health) as C_Health
	return (
		health != null and not health.depleted and is_finite(health.current)
		and is_finite(health.base) and is_finite(health.value) and health.base > 0.0
		and health.value > 0.0 and health.current > 0.0
		and health.current <= health.value and health.current * change.fraction > 0.0
		and health.current - health.current * change.fraction > 0.0
	)


## Commits after the caller seals its receipt; no attack resistance or source-veto affects consent.
static func commit(change: HealthConsentChange) -> DamageResult:
	assert(can_apply(change), "Voluntary HP transactions require preflight before receipt commit")
	var world: World = ECS.world
	var actor: Entity = change.target
	var health: C_Health = actor.get_component(C_Health) as C_Health
	var request: DamageRequest = DamageRequest.new()
	request.target = actor
	request.target_id = ActorIdentityRules.trace_key_for(actor)
	request.origin_id = change.origin_id
	request.instigator_id = change.origin_id
	request.correlation_id = change.confirmation_key
	request.operation = DamageRequest.Operation.SACRIFICE
	request.amount = health.current * change.fraction
	var result: DamageResult = DamageResult.new()
	result.request = request
	var spatial: Node3D = actor as Node as Node3D
	if spatial != null:
		result.world_pose = spatial.global_transform

	# Receipt/stat observers see coherent data; common publication can synchronously retire actor.
	health.begin_transaction()
	HealthMutationService.apply(request, health, result, world)
	assert(result.outcome == DamageResult.Outcome.APPLIED)
	world.emit_event(DamageResult.EVENT, actor, result)
	health.end_transaction()
	return result
#endregion
