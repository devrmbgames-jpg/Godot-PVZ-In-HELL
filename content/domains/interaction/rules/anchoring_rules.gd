extends RefCounted
## Pure authored anchor configuration and physical rest-threshold calculations.
class_name AnchoringRules

const DIRECTION_EPSILON: float = 0.0001

#region Authored rest policy
## Checks authored stable-time, motion and support bounds.
static func valid_config(config: C_Anchorable) -> bool:
	return (
		is_finite(config.minimum_rest_seconds) and config.minimum_rest_seconds >= 0.0
		and is_finite(config.maximum_linear_speed) and config.maximum_linear_speed >= 0.0
		and is_finite(config.maximum_angular_speed) and config.maximum_angular_speed >= 0.0
		and is_finite(config.support_tolerance) and config.support_tolerance > 0.0
		and config.support_direction_local.is_finite()
		and config.support_direction_local.length_squared() > DIRECTION_EPSILON * DIRECTION_EPSILON
	)


## Tests actual physical speed against authored rest thresholds.
static func within_motion_limits(body: RigidBody3D, config: C_Anchorable) -> bool:
	return (
		body.linear_velocity.length() <= config.maximum_linear_speed
		and body.angular_velocity.length() <= config.maximum_angular_speed
	)

#endregion
