extends RefCounted
## Typed factory notification for independent consumers and fixtures.
class_name HazardSpawnResult

const EVENT: StringName = &"hazard_spawned"

## Created effect and durable request/origin identifiers.
var hazard: Entity = null
var request_id: String = ""
var origin_id: String = ""
