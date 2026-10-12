extends RefCounted
## Synchronous permanent Strength/Health transaction; ordinary hits retain the DamageRequest owner.
class_name CharacterStatsTransactionService


#region Validated permanent attribute operation
## Reads all required attributes and finite postconditions before any ledger/stat commit.
static func can_apply(change: CharacterStatsChange) -> bool:
	if (
		change == null or not EntityAvailability.contains(change.target, ECS.world)
		or not change.target.enabled or change.target.has_component(C_Death)
		or not is_finite(change.strength_delta) or change.strength_delta <= 0.0
		or not is_finite(change.maximum_health_delta)
		or change.maximum_health_delta >= 0.0 or change.confirmation_key.is_empty()
	):
		return false
	var health: C_Health = change.target.get_component(C_Health) as C_Health
	var strength: C_Strength = change.target.get_component(C_Strength) as C_Strength
	return (
		health != null and strength != null and not health.depleted and is_finite(health.current)
		and health.current > 0.0 and is_finite(health.base) and is_finite(health.value)
		and health.base + change.maximum_health_delta > 0.0
		and health.value + change.maximum_health_delta > 0.0 and is_finite(strength.base)
		and is_finite(strength.value) and is_finite(strength.base + change.strength_delta)
		and is_finite(strength.value + change.strength_delta)
	)


## Commits one preflighted change and publishes common Health depletion after all stats are visible.
static func commit(change: CharacterStatsChange) -> DamageResult:
	assert(can_apply(change), "Permanent stat transactions must preflight before ledger commit")
	var world: World = ECS.world
	var actor: Entity = change.target
	var health: C_Health = actor.get_component(C_Health) as C_Health
	var strength: C_Strength = actor.get_component(C_Strength) as C_Strength
	var request: DamageRequest = DamageRequest.new()
	request.target = actor
	request.target_id = ActorIdentityRules.trace_key_for(actor)
	request.origin_id = change.origin_id
	request.instigator_id = change.origin_id
	request.correlation_id = change.confirmation_key
	request.operation = DamageRequest.Operation.SACRIFICE
	request.maximum_health_delta = change.maximum_health_delta
	request.amount = health.current if change.forfeit_life else 0.0
	var result: DamageResult = DamageResult.new()
	result.request = request
	var spatial: Node3D = actor as Node as Node3D
	if spatial != null:
		result.world_pose = spatial.global_transform

	# No property callback can observe one attribute changed while another is still old.
	health.begin_transaction()
	strength.begin_transaction()
	strength.base += change.strength_delta
	strength.value += change.strength_delta
	HealthMutationService.apply(request, health, result, world)
	assert(result.outcome != DamageResult.Outcome.REJECTED)

	# Publication may remove/reset the receiver synchronously; only captured Resources remain below.
	world.emit_event(DamageResult.EVENT, actor, result)
	health.end_transaction()
	strength.end_transaction()
	return result
#endregion
