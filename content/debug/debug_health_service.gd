extends RefCounted
## Developer-only Health/living lifecycle entry points.
class_name DebugHealthService


static func apply_damage(
	target: DebugTarget,
	amount: float,
	damage_type: DamageRequest.Type,
) -> DebugServiceResult:
	return _submit(target, amount, DamageRequest.Operation.DAMAGE, damage_type)


static func heal(target: DebugTarget, amount: float) -> DebugServiceResult:
	if EntityAvailability.contains(target.entity, ECS.world):
		var health: C_Health = target.entity.get_component(C_Health) as C_Health
		if health != null and (health.depleted or target.entity.has_component(C_Death)):
			var blocked: DebugServiceResult = DebugServiceResult.new()
			blocked.message = "target is depleted; use reset for living entities"
			return blocked
	return _submit(
		target,
		amount,
		DamageRequest.Operation.HEAL,
		DamageRequest.Type.GENERIC,
	)


static func kill(target: DebugTarget) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if not EntityAvailability.contains(target.entity, ECS.world):
		result.message = "target has no live Entity"
		return result

	var health: C_Health = target.entity.get_component(C_Health) as C_Health
	if health == null:
		result.message = "target has no C_Health"
		return result
	if health.depleted or health.current <= 0.0:
		result.message = "target is already depleted"
		return result
	return _submit(
		target,
		maxf(health.current, 0.001),
		DamageRequest.Operation.DAMAGE,
		DamageRequest.Type.GENERIC,
	)


static func reset(target: DebugTarget) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if not EntityAvailability.contains(target.entity, ECS.world):
		result.message = "target has no live Entity"
		return result

	var entity: Entity = target.entity
	if not entity.has_component(C_Living):
		result.message = "reset requires a live C_Living entity"
		return result

	var health: C_Health = entity.get_component(C_Health) as C_Health
	if health == null or not is_finite(health.value) or health.value <= 0.0:
		result.message = "target has invalid Health"
		return result

	GrabService.entity_unavailable(entity)
	PushService.entity_unavailable(entity)
	CartTransportService.entity_unavailable(entity)

	var control: C_GrabControl = entity.get_component(C_GrabControl) as C_GrabControl
	if control != null:
		control.captures.clear()
		control.rotation_active = false
		control.context_wheel_requested = false

	var interactor: C_Interactor = entity.get_component(C_Interactor) as C_Interactor
	if interactor != null:
		interactor.target = null
		interactor.physics_target = null
		interactor.prompt_text = ""

	var motion: C_Motion = entity.get_component(C_Motion) as C_Motion
	if motion != null:
		motion.control_enabled = true
		motion.pending_impulse = Vector3.ZERO

	if entity.has_component(C_Death):
		entity.remove_component(C_Death)
	var previous: float = health.current
	health.depleted = false
	health.current = health.value

	result.success = true
	result.message = "living entity reset"
	result.details.append("entity=%s" % entity.id)
	result.details.append("hp=%.1f -> %.1f" % [previous, health.current])
	return result


static func _submit(
	target: DebugTarget,
	amount: float,
	operation: DamageRequest.Operation,
	damage_type: DamageRequest.Type,
) -> DebugServiceResult:
	var result: DebugServiceResult = DebugServiceResult.new()
	if not is_finite(amount) or amount <= 0.0:
		result.message = "amount must be a finite positive number"
		return result
	if not EntityAvailability.contains(target.entity, ECS.world):
		result.message = "target has no live Entity"
		return result
	var entity: Entity = target.entity
	var health: C_Health = entity.get_component(C_Health) as C_Health
	if health == null:
		result.message = "target has no C_Health"
		return result

	var request: DamageRequest = DamageRequest.new()
	request.target = entity
	request.instigator = DebugTargetResolver.player()
	request.amount = amount
	request.operation = operation
	request.damage_type = damage_type
	if not DamageRequestService.submit(request):
		result.message = "DamageRequestService rejected request"
		return result

	result.success = true
	result.message = "health request submitted"
	result.details.append("entity=%s" % entity.id)
	result.details.append("hp_before=%.1f/%.1f" % [health.current, health.value])
	result.details.append("amount=%.1f" % amount)
	result.details.append(
		"operation=%s" % String(DamageRequest.Operation.keys()[operation])
	)
	result.details.append(
		"type=%s" % String(DamageRequest.Type.keys()[damage_type])
	)
	return result
