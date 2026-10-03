extends RefCounted
## Detached, validated one-time spawn proposal. Caller frees entity if payment fails.
class_name PreparedFurniture

var entity: Entity = null
var parent: Node3D = null
var world_pose: Transform3D = Transform3D.IDENTITY
