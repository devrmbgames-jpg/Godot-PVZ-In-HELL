extends Observer
## Единственный обычный расчёт здоровья; публикует результат без доменных реакций смерти.
class_name O_Damage


#region Подписка на запросы
## Подписывается на запросы конкретных целей с Health.
func query() -> QueryBuilder:
	return q.with_all([C_Health]).on_event(DamageRequest.EVENT)


## Проверяет тип и адрес запроса, затем ставит расчёт в CommandBuffer.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var request: DamageRequest = payload as DamageRequest
	if request == null or request.target != entity:
		return

	cmd.add_custom(_resolve.bind(request))


#endregion

#region Единственный расчёт здоровья
func _resolve(request: DamageRequest) -> void:
	var result: DamageResult = DamageResult.new()
	result.request = request
	if EntityAvailability.contains(request.target, _world):
		var spatial: Node3D = request.target as Node as Node3D
		if spatial != null:
			result.world_pose = spatial.global_transform
		var health: C_Health = request.target.get_component(C_Health) as C_Health
		if health != null:
			_apply(request, health, result)

	# Уведомить об отклонении даже при исчезновении цели после снимка запроса.
	var target: Entity = request.target if is_instance_valid(request.target) else null
	var trace_stage: BoundaryTraceEntry.Stage = BoundaryTraceEntry.Stage.COMPLETED
	if result.outcome == DamageResult.Outcome.REJECTED:
		trace_stage = BoundaryTraceEntry.Stage.REJECTED
	BoundaryTrace.record(&"damage.resolve", request.correlation_id, trace_stage, result.reason,
		request.origin_id, request.target_id)
	_world.emit_event(DamageResult.EVENT, target, result)


func _apply(request: DamageRequest, health: C_Health, result: DamageResult) -> void:
	var valid_amount: bool = is_finite(request.amount) and request.amount > 0.0
	var valid_health: bool = (
		is_finite(health.current) and is_finite(health.value) and health.value > 0.0
	)
	if not valid_amount or not valid_health or health.depleted or health.current <= 0.0:
		result.reason = &"invalid_health_or_amount"
		return
	if request.source != null and not EntityAvailability.contains(request.source, _world):
		result.reason = &"source_unavailable"
		return
	if request.operation not in [DamageRequest.Operation.DAMAGE, DamageRequest.Operation.HEAL]:
		result.reason = &"invalid_operation"
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

	var effective_amount: float = request.amount if is_heal else DamageResistanceRules.effective(request.target, request.amount, request.damage_type)
	var signed_amount: float = effective_amount if is_heal else -effective_amount
	result.current_value = clampf(result.previous_value + signed_amount, 0.0, health.value)
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

#endregion
