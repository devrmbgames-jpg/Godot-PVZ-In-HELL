extends RefCounted
## Captured transient command; weak owners and incarnation are revalidated at queued commit.
class_name SmartObjectRequest

const EVENT: StringName = &"smart_object_requested"
enum Operation {
	ACQUIRE,
	EXECUTE,
	CANCEL,
	USE,
}

## Requested operation; USE acquires, executes and retires in one owning operation.
var operation: Operation = Operation.ACQUIRE
## Weak actor boundary, never a durable ownership link.
var actor: WeakRef = null
## Weak object boundary; a recreated stable ID cannot satisfy this request.
var object: WeakRef = null
## Captured Smart Object Component, rejecting replacement within the same Node/World.
var incarnation: C_SmartObject = null
## Captured World identity; an old World's queue cannot operate in the replacement World.
var world: WeakRef = null
## Immutable operation key selected at submission.
var affordance_id: StringName = &""
## Exact expected transient token for execute/cancel.
var token: StringName = &""
## Pending/terminal observation returned to the original caller.
var receipt: SmartObjectReceipt = null
