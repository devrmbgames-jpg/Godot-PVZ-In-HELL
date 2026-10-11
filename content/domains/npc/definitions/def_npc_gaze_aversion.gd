@tool
extends DEF_NpcTrait
## Typed gaze aversion: safe idle observation and a committed attack after prolonged direct gaze.
class_name DEF_NpcGazeAversion

## Preferred horizontal observation distance from the perceived player, in metres.
@export_range(1.0, 15.0) var watch_distance: float = 6.0
## Accepted distance deviation before repositioning, in metres; smaller than watch_distance.
@export_range(0.1, 4.0) var distance_tolerance: float = 1.0
## Minimum angle from the player's actual camera forward direction, in degrees.
@export_range(30.0, 120.0) var watch_angle_degrees: float = 60.0
## Solid layers blocking direct gaze and candidate observation positions; Areas are excluded.
@export_flags_3d_physics var visibility_mask: int = 31


#region Authored policy validation
func _init() -> void:
	kind = Kind.GAZE_AVERSION


func valid_configuration() -> bool:
	return (
		kind == Kind.GAZE_AVERSION and visibility_mask > 0 and is_finite(watch_distance)
		and watch_distance >= 1.0 and watch_distance <= 15.0 and is_finite(distance_tolerance)
		and distance_tolerance >= 0.1 and distance_tolerance < watch_distance
		and distance_tolerance <= 4.0 and is_finite(watch_angle_degrees)
		and watch_angle_degrees >= 30.0 and watch_angle_degrees <= 120.0
		and is_finite(gaze_alignment) and gaze_alignment >= 0.5 and gaze_alignment <= 1.0
		and is_finite(warning_seconds) and warning_seconds > 0.0 and is_finite(reaction_seconds)
		and reaction_seconds > 0.0 and is_finite(radius) and radius > 0.0
	)
#endregion
