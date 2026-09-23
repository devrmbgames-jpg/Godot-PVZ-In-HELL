extends System
## Sole queued Health arithmetic authority; publishes typed results for domain reactions.
class_name S_Damage

## Every processed request, including rejection.
signal damage_resolved(result: DamageResult)
## Published once when positive Health crosses zero.
signal health_depleted(target: Entity, result: DamageResult)

var _pending: Array[DamageRequest] = []


#region GECS
func deps() -> Dictionary[int, Array]:
	return { Runs.Before: [S_DayPhase] }


func query() -> QueryBuilder:
	process_empty = true
	return q


func process(_entities: Array[Entity], _components: Array, _delta: float) -> void:
	if _pending.is_empty():
		return
	var requests: Array[DamageRequest] = _pending
	_pending = []
	# Death cleanup may remove relationships; run it outside query iteration.
	for request: DamageRequest in requests:
		cmd.add_custom(_resolve.bind(request))
#endregion


#region Public API
## Producers submit one request per impact/tick. Signals may enqueue work for the next tick.
static func submit(request: DamageRequest) -> bool:
	if request == null or not is_instance_valid(ECS.world):
		return false
	for system: System in ECS.world.systems:
		if system is S_Damage and system.active:
			var damage_system: S_Damage = system as S_Damage
			damage_system.enqueue(request)
			return true
	return false


## Copies producer data so queued requests cannot be edited after submission.
func enqueue(request: DamageRequest) -> void:
	if request == null:
		return
	# Freeze producer data at submission; shared request mutation cannot alter queued damage.
	var snapshot: DamageRequest = DamageRequest.new()
	snapshot.source = request.source if is_instance_valid(request.source) else null
	snapshot.target = request.target if is_instance_valid(request.target) else null
	snapshot.amount = request.amount
	snapshot.operation = request.operation
	snapshot.damage_type = request.damage_type
	_pending.append(snapshot)
#endregion


#region Resolution
func _resolve(request: DamageRequest) -> void:
	var result: DamageResult = DamageResult.new()
	result.request = request
	if (
		is_instance_valid(request.target) and S_Grab.entity_available(request.target)
		and is_finite(request.amount) and request.amount > 0.0
	):
		var health: C_Health = request.target.get_component(C_Health) as C_Health
		if health != null:
			_resolve_health(request, health, result)

	if result.outcome != DamageResult.Outcome.REJECTED:
		ECS.world.emit_event(DamageResult.EVENT, request.target, result)
	damage_resolved.emit(result)
	if result.outcome == DamageResult.Outcome.HEALTH_DEPLETED:
		health_depleted.emit(request.target, result)


func _resolve_health(request: DamageRequest, health: C_Health, result: DamageResult) -> void:
	if (
		health.depleted or health.value <= 0.0 or not is_finite(health.base)
		or not is_finite(health.value) or health.base <= 0.0
	):
		return
	result.previous_value = clampf(health.value, 0.0, health.base)
	var signed_amount: float = (
		request.amount if request.operation == DamageRequest.Operation.HEAL else -request.amount
	)
	result.current_value = clampf(result.previous_value + signed_amount, 0.0, health.base)
	result.applied_amount = absf(result.current_value - result.previous_value)
	var becomes_depleted: bool = result.previous_value > 0.0 and result.current_value <= 0.0
	if becomes_depleted:
		health.depleted = true
	health.value = result.current_value
	result.outcome = DamageResult.Outcome.APPLIED
	if becomes_depleted:
		result.outcome = DamageResult.Outcome.HEALTH_DEPLETED

#endregion
