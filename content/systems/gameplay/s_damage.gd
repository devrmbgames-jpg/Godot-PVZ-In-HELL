extends System
class_name S_Damage

signal damage_resolved(result: DamageResult)
signal defeated(target: Entity, result: DamageResult)

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
		else:
			_resolve_package(request, result)
	damage_resolved.emit(result)


func _resolve_health(request: DamageRequest, health: C_Health, result: DamageResult) -> void:
	if (
		health.defeated or not is_finite(health.base)
		or not is_finite(health.value) or health.base <= 0.0
	):
		return
	result.previous_value = clampf(health.value, 0.0, health.base)
	var signed_amount: float = (
		request.amount if request.operation == DamageRequest.Operation.HEAL else -request.amount
	)
	result.current_value = clampf(result.previous_value + signed_amount, 0.0, health.base)
	result.applied_amount = absf(result.current_value - result.previous_value)
	var becomes_defeated: bool = result.current_value <= 0.0
	if becomes_defeated:
		health.defeated = true
	health.value = result.current_value
	result.outcome = DamageResult.Outcome.APPLIED
	if becomes_defeated:
		result.outcome = DamageResult.Outcome.DEFEATED
		_cleanup_defeat(request.target)
		defeated.emit(request.target, result)


func _resolve_package(request: DamageRequest, result: DamageResult) -> void:
	if request.operation != DamageRequest.Operation.DAMAGE:
		return
	var integrity: C_PackageIntegrity = request.target.get_component(C_PackageIntegrity)
	var package_state: C_PackageState = request.target.get_component(C_PackageState)
	if integrity == null or package_state == null or integrity.maximum <= 0.0:
		return
	if not is_finite(integrity.maximum) or not is_finite(integrity.remaining):
		return
	if package_state.damage == C_PackageState.Damage.DESTROYED:
		return
	result.previous_value = clampf(integrity.remaining, 0.0, integrity.maximum)
	integrity.remaining = maxf(0.0, result.previous_value - request.amount)
	result.current_value = integrity.remaining
	result.applied_amount = result.previous_value - result.current_value
	package_state.damage = (
		C_PackageState.Damage.DESTROYED
		if integrity.remaining <= 0.0
		else C_PackageState.Damage.DAMAGED
	)
	result.outcome = (
		DamageResult.Outcome.PACKAGE_DESTROYED
		if integrity.remaining <= 0.0
		else DamageResult.Outcome.PACKAGE_DAMAGED
	)
	if integrity.remaining <= 0.0:
		S_Marker.clear_marks(request.target)


func _cleanup_defeat(target: Entity) -> void:
	S_Grab.entity_unavailable(target)
	var motion: C_Motion = target.get_component(C_Motion) as C_Motion
	if motion != null:
		motion.control_enabled = false
	var interactor: C_Interactor = target.get_component(C_Interactor) as C_Interactor
	if interactor != null:
		for system: System in ECS.world.systems:
			if system is S_InteractionTargeting:
				(system as S_InteractionTargeting).set_highlight(interactor.target, false)
		interactor.target = null
		interactor.prompt_text = ""
#endregion
