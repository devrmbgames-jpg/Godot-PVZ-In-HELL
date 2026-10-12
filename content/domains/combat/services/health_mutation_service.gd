extends RefCounted
## One Health calculation shared by ordinary damage and explicit permanent attribute transactions.
class_name HealthMutationService


#region Common Health calculation
## Resolves one validated request against its captured World; the caller publishes the result.
static func apply(
	request: DamageRequest,
	health: C_Health,
	result: DamageResult,
	world: World,
) -> void:
	var valid_amount: bool = (
		is_finite(request.amount)
		and (
			request.amount > 0.0
			or (request.operation == DamageRequest.Operation.SACRIFICE and request.amount == 0.0)
		)
	)
	var valid_health: bool = (
		is_finite(health.current) and is_finite(health.value) and health.value > 0.0
	)
	if not valid_amount or not valid_health or health.depleted or health.current <= 0.0:
		result.reason = &"invalid_health_or_amount"
		return
	if request.source != null and not EntityAvailability.contains(request.source, world):
		result.reason = &"source_unavailable"
		return
	if request.operation not in [
		DamageRequest.Operation.DAMAGE,
		DamageRequest.Operation.HEAL,
		DamageRequest.Operation.SACRIFICE,
	]:
		result.reason = &"invalid_operation"
		return

	if (
		not is_finite(request.minimum_health_fraction)
		or request.minimum_health_fraction < 0.0 or request.minimum_health_fraction > 1.0
		or (
			request.operation != DamageRequest.Operation.DAMAGE
			and request.minimum_health_fraction != 0.0
		)
	):
		result.reason = &"invalid_health_floor"
		return

	if request.operation == DamageRequest.Operation.SACRIFICE:
		_apply_sacrifice(request, health, result)
		return
	if request.maximum_health_delta != 0.0:
		result.reason = &"invalid_maximum_delta"
		return

	result.previous_value = clampf(health.current, 0.0, health.value)
	result.current_value = result.previous_value
	var is_heal: bool = request.operation == DamageRequest.Operation.HEAL
	var blocked: bool = (
		not is_heal and is_instance_valid(request.source)
		and request.source.has_component(C_NoDamage)
	)
	if blocked:
		result.outcome = DamageResult.Outcome.BLOCKED
		result.reason = &"source_veto"
		return

	var effective_amount: float = (
		request.amount
		if is_heal
		else DamageResistanceRules.effective(request.target, request.amount, request.damage_type)
	)
	var signed_amount: float = effective_amount if is_heal else -effective_amount
	var lower_bound: float = minf(
		result.previous_value, health.value * request.minimum_health_fraction,
	)
	result.current_value = clampf(result.previous_value + signed_amount, lower_bound, health.value)
	result.applied_amount = absf(result.current_value - result.previous_value)
	var depleted: bool = result.previous_value > 0.0 and result.current_value <= 0.0
	# Зафиксировать истощение до setter current и возможных вложенных уведомлений.
	if depleted:
		health.depleted = true
	health.current = result.current_value
	result.outcome = (
		DamageResult.Outcome.HEALTH_DEPLETED if depleted else DamageResult.Outcome.APPLIED
	)
	result.reason = &"health_depleted" if depleted else &"applied"


## Voluntary forfeiture changes the limit and reconciles HP before ordinary depletion publication.
static func _apply_sacrifice(
	request: DamageRequest,
	health: C_Health,
	result: DamageResult,
) -> void:
	var delta: float = request.maximum_health_delta
	if (
		not is_finite(delta) or delta > 0.0 or not is_finite(health.base)
		or health.base + delta <= 0.0 or health.value + delta <= 0.0
	):
		result.reason = &"invalid_maximum_delta"
		return
	result.previous_value = clampf(health.current, 0.0, health.value)
	var new_limit: float = health.value + delta
	result.current_value = clampf(result.previous_value - request.amount, 0.0, new_limit)
	result.applied_amount = result.previous_value - result.current_value
	var depleted: bool = result.current_value <= 0.0
	health.begin_transaction()
	health.base += delta
	health.value = new_limit
	if depleted:
		health.depleted = true
	health.current = result.current_value
	result.outcome = (
		DamageResult.Outcome.HEALTH_DEPLETED if depleted else DamageResult.Outcome.APPLIED
	)
	result.reason = &"health_depleted" if depleted else &"applied"
	health.end_transaction()
#endregion
