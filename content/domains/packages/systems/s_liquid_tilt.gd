extends System
## Измеряет непрерывный наклон непустой жидкой посылки и однократно запрашивает протечку.
class_name S_LiquidTilt


#region Измерение наклона
## Выбирает включённые посылки с состоянием содержимого и данными наклона.
func query() -> QueryBuilder:
	return q.enabled().with_all([C_Package, C_PackageState, C_LiquidTilt]).iterate(
		[C_PackageState, C_LiquidTilt]
	)


## Накапливает непрерывные секунды опасного наклона; безопасное положение или пустая коробка сбрасывает таймер.
func process(entities: Array[Entity], components: Array, delta: float) -> void:
	var conditions: Array = components[0]
	var tilts: Array = components[1]
	for index: int in entities.size():
		var condition: C_PackageState = conditions[index]
		var tilt: C_LiquidTilt = tilts[index]
		if PackageContentsService.is_empty(entities[index]):
			tilt.unsafe_seconds = 0.0
			continue
		if tilt.triggered or condition.leaking:
			continue
		if condition.damage == C_PackageState.Damage.DESTROYED:
			continue

		var body: Node3D = entities[index] as Node as Node3D
		if body == null:
			continue

		var up_alignment: float = body.global_basis.y.normalized().dot(Vector3.UP)
		var safe_alignment: float = cos(deg_to_rad(tilt.maximum_angle_degrees))
		if up_alignment >= safe_alignment:
			tilt.unsafe_seconds = 0.0
			continue

		tilt.unsafe_seconds += delta
		if tilt.unsafe_seconds >= tilt.duration_seconds:
			tilt.triggered = true
			cmd.add_custom(_commit_leak.bind(weakref(entities[index]), condition, tilt.damage_amount))


#endregion

#region Принятие протечки
func _commit_leak(entity_reference: WeakRef, condition: C_PackageState, amount: float) -> void:
	# Resolve queued owners before passing them to typed gameplay operations.
	var entity: Entity = entity_reference.get_ref() as Entity

	if not EntityAvailability.contains(entity, _world) or entity.get_component(C_PackageState) != condition or condition.leaking:
		return
	if PackageContentsService.is_empty(entity):
		return
	if condition.damage == C_PackageState.Damage.DESTROYED:
		return

	condition.leaking = true
	var newly_damaged: bool = condition.damage == C_PackageState.Damage.UNDAMAGED
	condition.damage = C_PackageState.Damage.DAMAGED
	if newly_damaged:
		PackageLifecycle.publish(entity, PackageLifecycleEvent.Kind.Damaged)
	PackageLifecycle.publish(entity, PackageLifecycleEvent.Kind.Leaking)

	if amount > 0.0 and EntityAvailability.contains(entity, _world):
		var request: DamageRequest = DamageRequest.new()
		request.target = entity
		request.amount = amount
		request.damage_type = DamageRequest.Type.LIQUID
		DamageRequestService.submit(request)

#endregion
