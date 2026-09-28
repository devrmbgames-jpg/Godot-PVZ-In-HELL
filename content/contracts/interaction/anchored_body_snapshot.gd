extends RefCounted
## Single reversible snapshot for every RigidBody property changed by player anchoring.
class_name AnchoredBodySnapshot

var freeze: bool = false
var freeze_mode: RigidBody3D.FreezeMode = RigidBody3D.FREEZE_MODE_STATIC
var can_sleep: bool = true
var sleeping: bool = false
var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
