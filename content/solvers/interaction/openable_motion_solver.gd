extends RefCounted
## Pure physical motion proposals; body callbacks own transforms and report actual fractions separately.
class_name OpenableMotionSolver

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
