extends Observer
## Принимает обычные запросы здоровья; общий расчёт публикует результат для доменных реакций.
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
			HealthMutationService.apply(request, health, result, _world)

	# Уведомить об отклонении даже при исчезновении цели после снимка запроса.
	var target: Entity = request.target if is_instance_valid(request.target) else null
	var trace_stage: BoundaryTraceEntry.Stage = BoundaryTraceEntry.Stage.COMPLETED
	if result.outcome == DamageResult.Outcome.REJECTED:
		trace_stage = BoundaryTraceEntry.Stage.REJECTED
	BoundaryTrace.record(
		&"damage.resolve",
		request.correlation_id,
		trace_stage,
		result.reason,
		request.origin_id,
		request.target_id,
	)
	_world.emit_event(DamageResult.EVENT, target, result)

#endregion
