extends RefCounted
## Generic one-shot spawn intent; no knowledge of packages, barrels or customer classes.
class_name HazardSpawnRequest

const EVENT: StringName = &"hazard_spawn_requested"

## Caller-supplied idempotency key and stable origin identity.
var request_id: String = ""
var origin_id: String = ""
var instigator_id: String = ""
## Autonomous authored hazard prefab and world-space snapshot.
var scene: PackedScene = null
var world_pose: Transform3D = Transform3D.IDENTITY
var origin: Entity = null
var instigator: Entity = null
## Sticky source-side veto snapshot; factories may strengthen but never clear it.
var damage_blocked: bool = false
