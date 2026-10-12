extends RefCounted
## Observable committed blood outcome; replays return the same durable receipt.
class_name BloodConsentResult

## Offer identity, including rejected submissions.
var confirmation_key: StringName = &""
## Terminal durable receipt, or null when no valid operation was committed.
var receipt: BloodConsentRecord = null
## Committed outcome or an explicit rejection reason.
var reason: StringName = &"invalid_request"
## True returns an existing result without repeating Health mutation.
var replayed: bool = false
