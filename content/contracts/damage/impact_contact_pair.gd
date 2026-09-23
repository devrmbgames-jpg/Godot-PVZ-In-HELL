extends RefCounted
## Per-World pair lifetime; one resolution per contact episode, rearmed by physical separation.
class_name ImpactContactPair

## Nodes are not owned by this record and may disappear at any time.
var first: PhysicsBody3D = null
var second: PhysicsBody3D = null
var resolved: bool = false
## Separation tick prevents a delayed snapshot from starting a fresh episode.
var separated_tick: int = -1
