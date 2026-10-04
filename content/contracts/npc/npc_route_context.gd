extends RefCounted
## Effective hazard inputs captured once for a route's health-risk check.
class_name NpcRouteContext

## Effective damaging sphere captured from a live hazard.
class Hazard extends RefCounted:
	## World center at the start of this plan.
	var center: Vector3 = Vector3.ZERO
	## Clearance including the traveler's physical radius.
	var radius: float = 0.0
	## Effective damage per second after the traveler's resistance.
	var damage_rate: float = 0.0

## Harmful volumes with resistance and clearance already applied.
var hazards: Array[Hazard] = []
## Actual movement speed used for exposure duration.
var speed: float = 1.0
