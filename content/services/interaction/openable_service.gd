extends RefCounted
## Common logical transitions and bounded motion proposals; never moves a Godot body.
class_name OpenableService

enum Operation { OPEN, CLOSE, UNLOCK }


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


static func request(actor: Entity, target: Entity, operation: Operation) -> bool:
	if not can_request(actor, target, operation):
		return false
	var state: C_Openable = target.get_component(C_Openable) as C_Openable
	match operation:
		Operation.OPEN:
			state.requested_open = true
		Operation.CLOSE:
			state.requested_open = false
		Operation.UNLOCK:
			if not ItemAccessService.fulfill(actor, state.access):
				return false
			state.locked = false
	return true


## A blocked controller reports its unchanged actual fraction, so intent alone
## cannot falsely mark an obstruction as passed or the object as fully open.
static func report_fraction(state: C_Openable, fraction: float) -> bool:
	if state == null or not is_finite(fraction) or fraction < 0.0 or fraction > 1.0:
		return false
	state.actual_fraction = fraction
	return true


static func proposed_fraction(state: C_Openable, delta: float) -> float:
	if state == null:
		return 0.0
	if state.locked or state.motion == null or not is_finite(delta) or delta < 0.0:
		return state.actual_fraction
	var duration: float = state.motion.duration_seconds
	if not is_finite(duration) or duration <= 0.0:
		return state.actual_fraction
	return move_toward(state.actual_fraction, 1.0 if state.requested_open else 0.0, delta / duration)


static func local_transform(motion: DEF_OpenableMotion, fraction: float) -> Transform3D:
	if motion == null:
		return Transform3D.IDENTITY
	var bounded: float = clampf(fraction, 0.0, 1.0) if is_finite(fraction) else 0.0
	return motion.closed_transform.interpolate_with(motion.open_transform, bounded)
