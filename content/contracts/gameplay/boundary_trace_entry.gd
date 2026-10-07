extends RefCounted
## Immutable-by-contract diagnostic snapshot; never authorizes or replays gameplay effects.
class_name BoundaryTraceEntry

enum Stage { ACCEPTED, COMPLETED, REJECTED, DUPLICATE }

## Ordered diagnostic sequence within this World session.
var sequence: int = 0
## Discoverable domain operation, such as damage.resolve or commerce.purchase.
var operation: StringName = &""
## Command/result correlation, independent of the diagnostic sequence.
var correlation_id: StringName = &""
## Acceptance is pending; completion follows authoritative mutation.
var stage: Stage = Stage.ACCEPTED
## Stable machine-readable reason; presentation may translate it separately.
var reason: StringName = &""
## Explicit domain/entity identity of the operation origin, when present.
var origin_id: String = ""
## Explicit identity of the target, visit, quest or transaction.
var target_id: String = ""

#region Detached diagnostics
## Returns detached scalar data without live Entity references or mutable gameplay state.
func snapshot() -> Dictionary[String, Variant]:
	return {
		"sequence": sequence,
		"operation": operation,
		"correlation_id": correlation_id,
		"stage": stage,
		"reason": reason,
		"origin_id": origin_id,
		"target_id": target_id,
	}
#endregion
