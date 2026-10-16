extends RefCounted
## Чистый предел суммарной внешней реакции; не ограничивает locomotion или гравитацию.
class_name KinematicExternalMotionRules


#region Предел реакции
## Объединение выполняет физический owner до вызова; velocity выражена в мировых м/с.
static func limit_velocity(velocity: Vector3, config: C_CharacterBody) -> Vector3:
	if not config.bounded_external_motion:
		return velocity
	var planar: Vector3 = Vector3(velocity.x, 0.0, velocity.z).limit_length(
		maxf(0.0, config.maximum_external_planar_speed),
	)
	return Vector3(planar.x, minf(velocity.y, config.maximum_external_upward_speed), planar.z)
#endregion
