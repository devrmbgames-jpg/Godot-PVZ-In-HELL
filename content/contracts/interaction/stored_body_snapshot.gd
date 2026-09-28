extends RefCounted
## Reversible physical attachment state; contains no Entity ownership.
class_name StoredBodySnapshot

var freeze: bool = false
var freeze_mode: RigidBody3D.FreezeMode = RigidBody3D.FREEZE_MODE_STATIC
var collision_layer: int = 0
var collision_mask: int = 0
var physics_processing: bool = false
var top_level: bool = false
