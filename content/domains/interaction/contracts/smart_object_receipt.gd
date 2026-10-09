extends RefCounted
## One request's terminal observation; this receipt is not live reservation authority.
class_name SmartObjectReceipt

enum Status {
	PENDING,
	ACQUIRED,
	SUCCEEDED,
	CANCELLED,
	REJECTED,
}

## Assigned only by the owning queued operation, after the described mutation is visible.
var status: Status = Status.PENDING
## Diagnostic rejection/commit category for callers.
var reason: StringName = &"pending"
## Captured acquisition token; callers must present it for execute/cancel.
var token: StringName = &""
