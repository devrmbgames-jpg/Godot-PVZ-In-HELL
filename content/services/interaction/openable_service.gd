extends RefCounted
## Владеет логическими переходами и предложением движения; физическое тело не перемещает.
class_name OpenableService

enum Operation { OPEN, CLOSE, UNLOCK }

## Допуск доли открытия для подтверждения достижения: мотор подходит к границе асимптотически.
const ENDPOINT_TOLERANCE: float = 0.02


#region Логический запрос и физическое подтверждение
## Проверяет доступность, замок, состояние повреждённой двери и требование предмета.
static func can_request(actor: Entity, target: Entity, operation: Operation) -> bool:
	if not GrabService.holder_available(actor) or not GrabService.entity_available(target):
		return false

	var state: C_Openable = target.get_component(C_Openable) as C_Openable
	var interactable: C_Interactable = target.get_component(C_Interactable) as C_Interactable
	if state == null or (interactable != null and not interactable.enabled):
		return false

	var breakable: C_BreakableDoor = target.get_component(C_BreakableDoor) as C_BreakableDoor
	var health: C_Health = target.get_component(C_Health) as C_Health
	if breakable != null and health != null:
		if breakable.mode == C_BreakableDoor.Mode.LEAF and health.depleted:
			return false
		if breakable.mode == C_BreakableDoor.Mode.PADLOCK and not health.depleted and operation == Operation.UNLOCK:
			return false

	match operation:
		Operation.OPEN:
			return not state.locked and not state.requested_open

		Operation.CLOSE:
			return not state.locked and (state.requested_open or state.actual_fraction > 0.0)

		Operation.UNLOCK:
			return state.locked and ItemAccessService.evaluate(actor, state.access).is_allowed()
	return false


## Повторно проверяет запрос; разблокировка подтверждает доступ, открытие меняет только намерение.
static func request(actor: Entity, target: Entity, operation: Operation) -> bool:
	if not can_request(actor, target, operation):
		return false

	var state: C_Openable = target.get_component(C_Openable) as C_Openable
	match operation:
		Operation.OPEN:
			state.requested_open = true
			_track_player_request(actor, target, true, state.actual_fraction < 1.0 - ENDPOINT_TOLERANCE)
		Operation.CLOSE:
			state.requested_open = false
			_track_player_request(actor, target, false, state.actual_fraction > ENDPOINT_TOLERANCE)
		Operation.UNLOCK:
			if not ItemAccessService.fulfill(actor, state.access):
				return false

			state.locked = false
	return true


## Фиксирует измеренную долю 0–1; заблокированный контроллер сообщает неизменное положение,
## поэтому одно намерение не подтверждает проход препятствия или полное открытие.
static func report_fraction(state: C_Openable, fraction: float, target: Entity = null) -> bool:
	if state == null or not is_finite(fraction) or fraction < 0.0 or fraction > 1.0:
		return false

	state.actual_fraction = fraction
	if EntityAvailability.contains(target, ECS.world) and target.get_component(C_Openable) == state:
		_complete_player_request(target, state)
	return true


## Удаляет атрибуцию ожидающего запроса игрока, не меняя физическое положение.
static func cancel_player_request(target: Entity) -> void:
	if not is_instance_valid(target):
		return

	for binding: Relationship in target.relationships.duplicate():
		if binding.relation is R_OpenableRequestedBy:
			target.remove_relationship(binding)


#endregion

#region Атрибуция запроса игрока
static func _track_player_request(actor: Entity, target: Entity, goal_open: bool, needs_motion: bool) -> void:
	cancel_player_request(target)
	if not needs_motion or not actor.has_component(C_PlayerInputController):
		return

	var pending: R_OpenableRequestedBy = R_OpenableRequestedBy.new()
	pending.goal_open = goal_open
	target.add_relationship(Relationship.new(pending, actor))


static func _complete_player_request(target: Entity, state: C_Openable) -> void:
	for binding: Relationship in target.relationships.duplicate():
		var pending: R_OpenableRequestedBy = binding.relation as R_OpenableRequestedBy
		if pending == null:
			continue

		var actor: Entity = binding.target as Entity if is_instance_valid(binding.target) else null
		if not GrabService.holder_available(actor) or pending.goal_open != state.requested_open or state.locked:
			target.remove_relationship(binding)
			continue

		var reached: bool = state.actual_fraction >= 1.0 - ENDPOINT_TOLERANCE if pending.goal_open else state.actual_fraction <= ENDPOINT_TOLERANCE
		if reached:
			# Связь удаляется первой: вложенный подписчик не увидит тот же ожидающий переход.
			target.remove_relationship(binding)
			PlayerInteractionEvents.publish(actor, target, PlayerInteractionEvent.Kind.DOOR_OPENED if pending.goal_open else PlayerInteractionEvent.Kind.DOOR_CLOSED)


#endregion

#region Предложение движения
## Предлагает ограниченную долю движения за delta секунд, сохраняя положение при замке или ошибке.
static func proposed_fraction(state: C_Openable, delta: float) -> float:
	if state == null:
		return 0.0
	if state.locked or state.motion == null or not is_finite(delta) or delta < 0.0:
		return state.actual_fraction

	var duration: float = state.motion.duration_seconds
	if not is_finite(duration) or duration <= 0.0:
		return state.actual_fraction
	return move_toward(state.actual_fraction, 1.0 if state.requested_open else 0.0, delta / duration)


## Интерполирует авторские локальные положения по ограниченной доле 0–1.
static func local_transform(motion: DEF_OpenableMotion, fraction: float) -> Transform3D:
	if motion == null:
		return Transform3D.IDENTITY

	var bounded: float = clampf(fraction, 0.0, 1.0) if is_finite(fraction) else 0.0
	return motion.closed_transform.interpolate_with(motion.open_transform, bounded)

#endregion
