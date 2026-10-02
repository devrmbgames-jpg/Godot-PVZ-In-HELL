extends Observer
## Read-only committed-hit notification. Register before destructive lifecycle observers.
class_name O_DamageFeedback

signal received(feedback: DamageFeedback)


func query() -> QueryBuilder:
	return q.with_all([C_Health]).on_event(DamageResult.EVENT)


func each(_event: Variant, entity: Entity, payload: Variant = null) -> void:
	var result: DamageResult = payload as DamageResult
	if result == null or result.request == null or not is_instance_valid(entity) or result.request.target != entity or result.request.operation != DamageRequest.Operation.DAMAGE:
		return
	if result.outcome not in [DamageResult.Outcome.APPLIED, DamageResult.Outcome.HEALTH_DEPLETED] or not is_finite(result.applied_amount) or result.applied_amount <= 0.0:
		return
	var feedback: DamageFeedback = DamageFeedback.new()
	feedback.target_id = entity.id
	feedback.damage_type = result.request.damage_type
	feedback.amount = result.applied_amount
	feedback.position = result.world_pose.origin
	feedback.depleted = result.outcome == DamageResult.Outcome.HEALTH_DEPLETED
	var instigator: Entity = result.request.instigator
	feedback.actor_is_player = is_instance_valid(instigator) and instigator.has_component(C_PlayerInputController)
	if entity.has_component(C_PlayerInputController):
		feedback.audience = DamageFeedback.Audience.PLAYER
	elif entity.has_component(C_Package):
		feedback.audience = DamageFeedback.Audience.PACKAGE
		feedback.package_id = (entity.get_component(C_Package) as C_Package).package_id
	received.emit(feedback)
