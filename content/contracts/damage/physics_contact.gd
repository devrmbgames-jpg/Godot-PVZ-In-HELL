extends RefCounted
## Snapshot of one body's contact manifold; normal speed and impulse are scalar SI values.
class_name PhysicsContact

## Physical participants (environment bodies need not be Entities).
var body_a: PhysicsBody3D = null
var body_b: PhysicsBody3D = null
## Physics tick captured by the bridge, never render-frame time.
var tick: int = 0
var normal_speed: float = 0.0
var normal_impulse: float = 0.0
## World-space normal pointing toward body_a; used for explicit kinematic rebound.
var normal_on_a: Vector3 = Vector3.ZERO
