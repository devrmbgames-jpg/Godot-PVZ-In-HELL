extends Observer
## Maps generic applied Health damage to package condition without deleting physical wrecks.
class_name O_PackageDamage


func query() -> QueryBuilder:
	return q.with_all([C_PackageState]).on_event(DamageResult.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.request.operation != DamageRequest.Operation.DAMAGE:
		return
	if result.applied_amount <= 0.0:
		return
	cmd.add_custom(_commit_condition.bind(entity, result))


func _commit_condition(target: Entity, result: DamageResult) -> void:
	if not S_Grab.entity_available(target):
		return
	var condition: C_PackageState = target.get_component(C_PackageState) as C_PackageState
	if condition.damage == C_PackageState.Damage.DESTROYED:
		return
	if result.outcome == DamageResult.Outcome.HEALTH_DEPLETED:
		condition.damage = C_PackageState.Damage.DESTROYED
		S_CartCargo.release(target)
		S_Grab.entity_unavailable(target)
		S_Marker.clear_marks(target)
	else:
		condition.damage = C_PackageState.Damage.DAMAGED
