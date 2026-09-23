extends Observer
class_name O_Damage


func query() -> QueryBuilder:
	return q.with_all(
		[C_Health]
	).on_event(
		DamageRequest.EVENT
	)


func each(
	_event: Variant,
	entity: Entity,
	payload: Variant = null
) -> void:
	
	var request: DamageRequest = payload  as DamageRequest
	# TODO Валидация DamageRequest. Удалить если ударит по производительности
	assert(request, "Invalid damage payload")
	if not request:
		push_error("O_Damage: invalid damage payload")
		return
	
	assert(
		request.target == entity,
		"DamageRequest target does not match event entity"
	)
	if request.target != entity:
		push_error("O_Damage: target mismatch")
		return
	
	assert(
		is_finite(request.amount) and request.amount > 0.0,
		"Invalid damage amount"
	)
	if not is_finite(request.amount) or request.amount <= 0.0:
		return
	# ====
	
	var health: C_Health = entity.get_component(C_Health) as C_Health
	# TODO Валидация C_Health . Удалить если ударит по производительности
	assert(health != null, "Missing C_Health")
	if health == null:
		push_error("O_Damage: missing C_Health")
		return
	
	# Depletion terminal until explicit respawn.
	if health.depleted or health.current <= 0.0:
		return
	
	var is_heal: bool = (
		request.operation == DamageRequest.Operation.HEAL
	)

	var is_blocked: bool = (
		not is_heal
		and is_instance_valid(request.source)
		and request.source.has_component(C_NoDamage)
	)

	var previous_value: float = health.current

	# Не модифицируем request.amount.
	var effective_amount: float = (
		0.0 if is_blocked else request.amount
	)

	var signed_amount: float = (
		effective_amount if is_heal else -effective_amount
	)

	var new_value: float = clampf(
		previous_value + signed_amount,
		0.0,
		health.value
	)

	var depleted: bool = (
		not is_heal
		and previous_value > 0.0
		and new_value <= 0.0
	)

	# Commit Health before publishing the result.
	health.current = new_value

	if depleted:
		health.depleted = true

	var result := DamageResult.new()

	result.request = request
	result.previous_value = previous_value
	result.current_value = new_value
	result.applied_amount = absf(new_value - previous_value)

	if is_blocked:
		result.outcome = DamageResult.Outcome.BLOCKED
	elif depleted:
		result.outcome = DamageResult.Outcome.HEALTH_DEPLETED
	else:
		result.outcome = DamageResult.Outcome.APPLIED

	var spatial: Node3D = entity as Node as Node3D

	if spatial != null:
		result.world_pose = spatial.global_transform

	# Публикуем даже при is_blocked.
	ECS.world.emit_event(
		DamageResult.EVENT,
		entity,
		result
	)
