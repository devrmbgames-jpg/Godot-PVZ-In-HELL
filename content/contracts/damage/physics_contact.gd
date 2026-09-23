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
