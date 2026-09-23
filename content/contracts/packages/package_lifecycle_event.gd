extends RefCounted
## Typed R09/R11 hook for condition changes; no hazard/customer consequences are applied here.
class_name PackageLifecycleEvent

## Stable World event channel, carrying this record.
const EVENT: StringName = &"package_lifecycle"

enum Kind {
	Damaged,
	Destroyed,
	Opened,
	Leaking,
}

## Identity survives downstream removal; actor is the opener or attributed damage source.
var package_id: String = ""
var package: Entity = null
var actor: Entity = null
var kind: Kind = Kind.Damaged
var cause: DamageResult = null
