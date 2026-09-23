extends RefCounted
## Committed Health change, retaining its request and attribution for downstream lifecycle.
class_name DamageResult

## World event carrying this typed result.
const EVENT: StringName = &"health_damage_resolved"

enum Outcome {
	REJECTED,
	APPLIED,
	HEALTH_DEPLETED,
}

## Submitted snapshot, values and actual applied amount.
var request: DamageRequest = null
var outcome: Outcome = Outcome.REJECTED
var previous_value: float = 0.0
var current_value: float = 0.0
var applied_amount: float = 0.0

## Physics pose captured before any downstream lifecycle reaction can remove the target.
var world_pose: Transform3D = Transform3D.IDENTITY
