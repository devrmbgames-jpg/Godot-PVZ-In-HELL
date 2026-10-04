extends Observer
## Переводит результат урона Health в состояние коробки; обломки создаёт другой наблюдатель.
class_name O_PackageDamage


#region Подписка на урон
## Подписывается на результат урона для сущностей с состоянием коробки.
func query() -> QueryBuilder:
	return q.with_all([C_PackageState]).on_event(DamageResult.EVENT)


## При реальном положительном уроне откладывает переход состояния, не пересчитывая Health.
func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.request.operation != DamageRequest.Operation.DAMAGE:
		return
	if result.applied_amount <= 0.0:
		return

	cmd.add_custom(_commit_condition.bind(entity, result))


#endregion

#region Переход состояния коробки
func _commit_condition(target: Entity, result: DamageResult) -> void:
	if not GrabService.entity_available(target):
		return

	var condition: C_PackageState = target.get_component(C_PackageState) as C_PackageState
	if condition.damage == C_PackageState.Damage.DESTROYED:
		return
	if result.outcome == DamageResult.Outcome.HEALTH_DEPLETED:
		condition.damage = C_PackageState.Damage.DESTROYED
		CartCargoService.release(target)
		GrabService.entity_unavailable(target)
		PackageMarkService.clear_marks(target)
		PackageLifecycle.publish(
			target,
			PackageLifecycleEvent.Kind.Destroyed,
			result.request.source,
			result,
		)

#endregion
	elif condition.damage == C_PackageState.Damage.UNDAMAGED:
		var identity: C_Package = target.get_component(C_Package) as C_Package
		var health: C_Health = target.get_component(C_Health) as C_Health
		if identity == null or identity.definition == null or health == null:
			return

		var damaged_threshold: float = (
			health.value * identity.definition.damaged_health_ratio
		)
		if result.current_value > damaged_threshold:
			return

		condition.damage = C_PackageState.Damage.DAMAGED
		PackageLifecycle.publish(
			target,
			PackageLifecycleEvent.Kind.Damaged,
			result.request.source,
			result,
		)
