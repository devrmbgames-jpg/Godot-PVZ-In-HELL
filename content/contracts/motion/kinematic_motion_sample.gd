extends RefCounted
## Immutable-by-contract callback sample for one completed slide; neither gameplay authority nor persisted state.
class_name KinematicMotionSample

## Physical velocity before slide, consumed by the independent contact-impact contribution.
var incoming_velocity: Vector3
## Desired controlled velocity, consumed by the independent walking-push contribution.
var desired_velocity: Vector3

#region Callback sample construction
func _init(incoming: Vector3, desired: Vector3) -> void:
	incoming_velocity = incoming
	desired_velocity = desired
#endregion
