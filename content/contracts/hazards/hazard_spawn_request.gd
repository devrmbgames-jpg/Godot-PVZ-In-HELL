extends RefCounted
## Generic one-shot spawn intent; no knowledge of packages, barrels or customer classes.
class_name HazardSpawnRequest

const EVENT: StringName = &"hazard_spawn_requested"

## Caller-supplied idempotency key and stable origin identity.
var request_id: String = ""
var origin_id: String = ""
var instigator_id: String = ""
## Authored effect and world-space snapshot; origin may disappear after submission.
var definition: DEF_Hazard = null
var world_pose: Transform3D = Transform3D.IDENTITY
var origin: Entity = null
var instigator: Entity = null
## Explicit ownership policy, copied into runtime state at spawn.
var ownership: DEF_Hazard.Ownership = DEF_Hazard.Ownership.Independent
var owner_loss: DEF_Hazard.OwnerLoss = DEF_Hazard.OwnerLoss.Detach
## Sticky source-side veto snapshot; factories may strengthen but never clear it.
var damage_blocked: bool = false
